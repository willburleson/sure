# Chase 5/24 for one holder: cards opened in the last 24 months that report to
# personal credit. Issuers disagree on when a card stops counting (exactly 24
# months, or the first of the following month, and some count tradelines a bit
# longer), so the window carries a one-month buffer: a card counts until 25
# months after it opened. The dates shown are the earliest you are safe.
class RewardCard::FiveTwentyFour
  LIMIT = 5
  WINDOW = 25.months

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
