# Per-holder view model for the Cards page and the dashboard "Cards & points"
# section: 5/24 status, eligibility alerts and point estimates.
class RewardCard::Summary
  Holder = Data.define(:name, :cards, :eligibility, :estimates) do
    def five_twenty_four = eligibility.five_twenty_four
    def alerts = eligibility.alerts
    def open_cards = cards.select(&:open?)

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

  private
    def estimator
      @estimator ||= PointBalance::Estimator.new(family, today: today)
    end
end
