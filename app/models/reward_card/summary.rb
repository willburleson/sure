# Per-holder view model for the Cards page and the dashboard "Cards & points"
# section: 5/24 status, eligibility alerts and point estimates.
class RewardCard::Summary
  Holder = Data.define(:name, :cards, :eligibility, :estimates) do
    def five_twenty_four = eligibility.five_twenty_four
    def alerts = eligibility.alerts
    def open_cards = cards.select(&:open?)
    def closed_cards = cards.reject(&:open?)
    def held_products = open_cards.filter_map(&:product).to_set
    def needs_details = cards.select { |card| card.missing_details.any? }

    def average_open_age_months
      return nil if open_cards.empty?

      (open_cards.sum { |card| card.age_in_months(eligibility.today) }.to_f / open_cards.size).round
    end
  end

  attr_reader :family, :today

  def initialize(family, today: Date.current)
    @family = family
    @today = today
  end

  # Holders ordered by their oldest card, then anyone with only balances.
  def holder_names
    @holder_names ||= (
      family.reward_cards.group(:holder).order(Arel.sql("MIN(opened_on)")).pluck(:holder) +
      family.point_balances.distinct.order(:holder).pluck(:holder)
    ).uniq
  end

  def holders
    @holders ||= holder_names.map { |name| holder(name) }
  end

  def holder(name)
    cards = family.reward_cards.for_holder(name).includes(:account).chronological.to_a
    Holder.new(
      name: name,
      cards: cards,
      eligibility: RewardCard::Eligibility.new(cards, today: today),
      estimates: estimator.estimates_for(name)
    )
  end

  def any?
    holder_names.any?
  end

  # Balances summed across holders, per program, for the Household tab.
  HouseholdTotal = Data.define(:program, :total, :earned, :parts) do
    def catalog_program = RewardCard::Catalog.program(program)
    def cash? = catalog_program&.cash?
  end

  def household_totals
    holders.flat_map(&:estimates).select(&:balance).group_by(&:program).map do |program, estimates|
      HouseholdTotal.new(program: program, total: estimates.sum(&:total), earned: estimates.sum(&:earned),
                         parts: estimates.map { |estimate| [ estimate.holder, estimate.total ] })
    end.sort_by { |total| [ total.cash? ? 1 : 0, -total.total ] }
  end

  private
    def estimator
      @estimator ||= PointBalance::Estimator.new(family, today: today)
    end
end
