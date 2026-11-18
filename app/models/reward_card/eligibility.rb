# When a holder can next apply for (and get the bonus on) each catalog
# product, from that holder's card history and the rules in
# config/reward_cards.yml. Each rule yields a Blocker: a date it clears
# (past dates are kept so "newly eligible" can be shown), :close when a card
# must be closed first, :never, or :unknown when a rule needs a close date
# the history doesn't have.
class RewardCard::Eligibility
  UPCOMING_WINDOW = 90.days
  RECENT_WINDOW = 30.days

  Blocker = Data.define(:note, :until) do
    def active?(today) = !self.until.is_a?(Date) || self.until > today
  end

  Result = Data.define(:product, :blockers, :today) do
    def active_blockers = blockers.select { |blocker| blocker.active?(today) }

    def eligible_on
      return nil if blockers.any? { |blocker| !blocker.until.is_a?(Date) }

      blockers.map(&:until).max || today
    end

    def status
      return :never if blockers.any? { |blocker| blocker.until == :never }
      return :close_first if blockers.any? { |blocker| blocker.until == :close }
      return :check if blockers.any? { |blocker| blocker.until == :unknown }
      return :eligible if eligible_on <= today
      return :upcoming if eligible_on <= today + UPCOMING_WINDOW

      :waiting
    end

    # Became eligible in the last 30 days (a dated rule cleared recently).
    def newly_eligible?
      status == :eligible && blockers.any? && eligible_on > today - RECENT_WINDOW
    end

    def alert? = status == :upcoming || newly_eligible?

    # Which list the Cards page shows it in.
    def group
      return :coming_up if alert?
      return :eligible if status == :eligible

      :blocked
    end
  end

  # One issuer-level rule for the Issuer rules section: `blocker` is nil when
  # the rule is clear (or when it only applies to a specific card, `per_card`).
  IssuerRuleStatus = Data.define(:note, :blocker, :per_card) do
    def clear?(today) = blocker.nil? || !blocker.active?(today)
  end

  attr_reader :cards, :today

  def initialize(cards, today: Date.current)
    @cards = cards.to_a
    @today = today
  end

  def five_twenty_four
    @five_twenty_four ||= RewardCard::FiveTwentyFour.new(cards, today: today)
  end

  def results(products = RewardCard::Catalog.watched_products)
    products.map { |product| result_for(product) }.sort_by { |result| sort_key(result) }
  end

  def alerts
    results.select(&:alert?)
  end

  def result_for(product)
    rules = RewardCard::Catalog.issuer(product.issuer).rules + product.rules
    Result.new(product: product, blockers: rules.filter_map { |rule| evaluate(rule, product) }, today: today)
  end

  # How each of an issuer's own rules (not the per-card bonus rules) treats a
  # new personal or business card from this holder today.
  def issuer_rule_statuses(issuer_key, business: false)
    product = RewardCard::Catalog::Product.new(
      key: "issuer", name: issuer_key, issuer: issuer_key, family: nil, business: business,
      counts_toward_524: !business, program: nil, earn: {}, rules: [], watch: false
    )

    RewardCard::Catalog.issuer(issuer_key).rules.filter_map do |rule|
      next if (rule["scope"] == "issuer_personal" && business) || (rule["scope"] == "issuer_business" && !business)

      note = rule["note"] || default_note(rule)
      if rule["type"] == "lifetime" || rule["type"] == "not_holding" || %w[product family].include?(rule["scope"])
        IssuerRuleStatus.new(note: note, blocker: nil, per_card: true)
      else
        IssuerRuleStatus.new(note: note, blocker: evaluate(rule, product), per_card: false)
      end
    end
  end

  private
    def default_note(rule)
      rule["type"] == "five_24" ? "Chase 5/24: no new Chase card at #{RewardCard::FiveTwentyFour::LIMIT} or more personal cards in 24 months" : rule["type"]
    end

    def sort_key(result)
      rank = { upcoming: 0, eligible: 1, waiting: 2, check: 3, close_first: 4, never: 5 }.fetch(result.status)
      [ rank, result.eligible_on || Date.new(9999), result.product.name ]
    end

    def evaluate(rule, product)
      note = rule["note"]

      case rule["type"]
      when "five_24"
        return nil if five_twenty_four.under?

        Blocker.new(note: rule["note"] || "Over 5/24 (#{five_twenty_four.count} cards in 24 months)", until: five_twenty_four.under_on)
      when "velocity"
        velocity(rule, product, note)
      when "cooldown"
        cooldown(rule, product, note)
      when "not_holding"
        Blocker.new(note: note, until: :close) if in_scope(rule["scope"], product).any?(&:open?)
      when "lifetime"
        also = Array(rule["also"])
        had = in_scope(rule["scope"], product).select(&:bonus_received?) +
              cards.select { |card| also.include?(card.product) }
        Blocker.new(note: note, until: :never) if had.any?
      else
        raise ArgumentError, "unknown reward card rule #{rule["type"].inspect}"
      end
    end

    def velocity(rule, product, note)
      scope = rule["scope"]
      return nil if scope == "issuer_business" && !product.business
      return nil if scope == "issuer_personal" && product.business

      window = rule.fetch("days").days
      recent = in_scope(scope, product).map(&:opened_on).select { |date| date + window > today }.sort
      max = rule.fetch("max")
      return nil if recent.size < max

      Blocker.new(note: note, until: recent[recent.size - max] + window)
    end

    def cooldown(rule, product, note)
      scoped = in_scope(rule["scope"], product)
      if rule.fetch("from") == "close" && (undated = scoped.select(&:closed_date_unknown?)).any?
        return Blocker.new(note: "#{note}: add the close date for #{undated.map(&:display_name).uniq.to_sentence}", until: :unknown)
      end

      dates = scoped.filter_map do |card|
        case rule.fetch("from")
        when "bonus" then card.bonus_on
        when "open" then card.opened_on
        when "close" then card.closed_on
        end
      end
      return nil if dates.empty?

      Blocker.new(note: note, until: dates.max + rule.fetch("months").months)
    end

    def in_scope(scope, product)
      case scope
      when "product" then cards.select { |card| card.product == product.key }
      when "family" then cards.select { |card| card.product == product.key || (product.family && card.catalog_product&.family == product.family) }
      when "issuer" then cards.select { |card| card.issuer == product.issuer }
      when "issuer_personal" then cards.select { |card| card.issuer == product.issuer && !card.business? }
      when "issuer_business" then cards.select { |card| card.issuer == product.issuer && card.business? }
      when "all_524" then cards.select(&:counts_toward_524?)
      else raise ArgumentError, "unknown reward card rule scope #{scope.inspect}"
      end
    end
end
