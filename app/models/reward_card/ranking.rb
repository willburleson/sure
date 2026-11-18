# "Best to get next": the cards a holder is eligible for right now that have a
# current offer, with the order to apply in. Offers are shown as the actual
# points, miles or cash (Rakuten and other cash extras included), never
# converted to a common value, so they are grouped by reward program and
# ranked within each group.
#
# Order matters when one bonus would block another card but not the reverse
# (get a Venture X bonus and the Venture bonus is blocked for 48 months, but
# not the other way round; any non-Chase card makes a Chase app harder at 4/24).
# That is found by pretending to open each card today and re-running the rules
# for every other card, so it follows config/reward_cards.yml rather than a
# hard-coded list.
class RewardCard::Ranking
  Entry = Data.define(:result, :offer, :before, :after) do
    def product = result.product
  end

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

  # True when getting `first`'s bonus today would leave `second` blocked.
  def blocks?(first, second)
    blocked_by_hypothetical.fetch([ first.key, second.key ])
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
          # This card's bonus blocks `other` (not the reverse): `other` goes first.
          after = others.select { |other| blocks?(result.product, other) && !blocks?(other, result.product) }
          # `other`'s bonus blocks this card (not the reverse): this card goes first.
          before = others.select { |other| blocks?(other, result.product) && !blocks?(result.product, other) }
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
        pick = remaining.find { |entry| (entry.after.map(&:key) & keys_left).empty? } || remaining.first
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

    # { [first_key, second_key] => true when opening `first` today (bonus
    # received) leaves `second` blocked }.
    def blocked_by_hypothetical
      @blocked_by_hypothetical ||= begin
        candidates = eligibility.results.select { |result| result.status == :eligible }.map(&:product)
        candidates.product(candidates).to_h do |first, second|
          next [ [ first.key, second.key ], false ] if first.key == second.key

          card = RewardCard.new(holder: "hypothetical", name: first.name, issuer: first.issuer, product: first.key,
                                opened_on: today, bonus_received: true, business: first.business)
          rerun = RewardCard::Eligibility.new(eligibility.cards + [ card ], today: today)
          [ [ first.key, second.key ], rerun.result_for(second).active_blockers.any? ]
        end
      end
    end
end
