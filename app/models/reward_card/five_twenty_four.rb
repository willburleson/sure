# Chase 5/24 for one holder: cards opened in the last 24 months that report to
# personal credit. A card stops counting on the 24-month anniversary of its
# open date (some data points say the first of the following month, so treat
# the dates as earliest-possible).
class RewardCard::FiveTwentyFour
  LIMIT = 5
  WINDOW = 24.months

  attr_reader :cards, :today

  def initialize(cards, today: Date.current)
    @cards = cards
    @today = today
  end

  def counted
    @counted ||= cards.select { |card| card.counts_toward_524? && card.opened_on + WINDOW > today }.sort_by(&:opened_on)
  end

  def count = counted.size
  def under? = count < LIMIT

  # Dates each counted card drops off, oldest first.
  def drop_dates
    counted.map { |card| card.opened_on + WINDOW }
  end

  def next_drop_on = drop_dates.first

  # First date the holder is under 5/24 again (today when already under).
  def under_on
    under? ? today : drop_dates[count - LIMIT]
  end

  # Cards that can still be opened while staying under 5/24 for a Chase app.
  def slots
    [ LIMIT - 1 - count, 0 ].max
  end
end
