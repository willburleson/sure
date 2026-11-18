# "Best to get next": the cards a holder is eligible for right now that have a
# current offer, with the order to apply in. Offers are shown as the actual
# points, miles or cash (Rakuten and other cash extras included), never
# converted to a common value, so they are grouped by reward program and
# ranked within each group.
#
# Order matters when opening one card delays another longer than the reverse:
# a Venture X bonus blocks Venture for 48 months, while a Venture only delays
# Venture X by Capital One's 6-month spacing, so Venture goes first; at 4/24 any
# non-Chase card pushes a Chase app out until a card ages off. That is found by
# pretending to open each card today and re-running the rules for the other, so
# it follows config/reward_cards.yml rather than a hard-coded list.
class RewardCard::Ranking
  # `until` is when the card named in `product` (or this card) is available
  # again if the other order is used; NEVER when no date clears it.
  Delay = Data.define(:product, :until) do
    def indefinite? = self.until >= NEVER
  end

  Entry = Data.define(:result, :offer, :before, :after) do
    def product = result.product
  end

  NEVER = Date.new(9999, 12, 31)

  Group = Data.define(:program, :entries) do
    def cash? = program.nil? || program.cash?
  end

  attr_reader :eligibility, :today

  def initialize(eligibility, bonuses: RewardCard::Bonuses)
    @eligibility = eligibility
    @bonuses = bonuses
    @today = eligibility.today
  end

  def groups
    @groups ||= entries.group_by { |entry| entry.product.program }.map do |program_key, list|
      Group.new(program: RewardCard::Catalog.program(program_key), entries: order(list))
    end.sort_by { |group| [ group.cash? ? 0 : 1, -top_value(group) ] }
  end

  def any? = entries.any?

  # The date `second` is available again if `first` is opened today (its bonus
  # received): today when `first` does not delay it, NEVER when no date clears it.
  def delay(first, second)
    delays.fetch([ first.key, second.key ])
  end

  private
    def entries
      @entries ||= begin
        held = eligibility.cards.select(&:open?).filter_map(&:product).to_set
        results = eligibility.results.select { |result| result.status == :eligible && !held.include?(result.product.key) }
        offered = results.filter_map { |result| (offer = @bonuses.offer(result.product.key)) && [ result, offer ] }

        offered.map do |result, offer|
          # Against every card you are eligible for, offer or not: a Venture
          # still goes before Venture X when only the Venture has a listed offer.
          others = results.map(&:product).reject { |product| product.key == result.product.key }
          # `other` waits longer behind this card than this card waits behind
          # `other`: this card goes first.
          before = others.filter_map do |other|
            mine = delay(other, result.product)
            theirs = delay(result.product, other)
            Delay.new(product: other, until: mine) if mine > theirs
          end
          # The reverse: getting this card first costs `other` more than the
          # other order costs this one, so this card waits for it.
          after = others.filter_map do |other|
            mine = delay(other, result.product)
            theirs = delay(result.product, other)
            Delay.new(product: other, until: theirs) if theirs > mine
          end
          Entry.new(result: result, offer: offer, before: before, after: after)
        end
      end
    end

    # Highest offer first, except a card that has to wait for another one in
    # the same list is placed after it (a Kahn pass that always takes the
    # best-ranked card whose predecessors are already placed).
    def order(list)
      remaining = list.sort_by { |entry| sort_key(entry) }
      placed = []
      until remaining.empty?
        keys_left = remaining.map { |entry| entry.product.key }
        pick = remaining.find { |entry| (entry.after.map { |delay| delay.product.key } & keys_left).empty? } || remaining.first
        placed << remaining.delete(pick)
      end
      placed
    end

    def sort_key(entry)
      offer = entry.offer
      [ -(offer.cash? ? offer.cash_total : offer.amount), -offer.extra_cash, entry.product.name ]
    end

    def top_value(group)
      offer = group.entries.first.offer
      offer.cash? ? offer.cash_total : offer.amount
    end

    # { [first_key, second_key] => date `second` clears after `first` is opened today }.
    def delays
      @delays ||= begin
        candidates = eligibility.results.select { |result| result.status == :eligible }.map(&:product)
        candidates.product(candidates).to_h do |first, second|
          next [ [ first.key, second.key ], today ] if first.key == second.key

          card = RewardCard.new(holder: "hypothetical", name: first.name, issuer: first.issuer, product: first.key,
                                opened_on: today, bonus_received: true, business: first.business)
          rerun = RewardCard::Eligibility.new(eligibility.cards + [ card ], today: today).result_for(second)
          date = rerun.active_blockers.any? ? (rerun.eligible_on || NEVER) : today
          [ [ first.key, second.key ], date ]
        end
      end
    end
end
