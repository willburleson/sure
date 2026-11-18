require "test_helper"

class RewardCard::FiveTwentyFourTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @today = Date.new(2026, 11, 17)
  end

  test "counts personal cards opened in the last 25 months (24 plus a one-month buffer)" do
    cards = [
      card("2024-10-18"), card("2025-01-08"), card("2025-02-06"), card("2025-04-04"),
      card("2024-10-17"),                       # exactly 25 months ago: dropped off today
      card("2024-11-04", product: "chase_ink_unlimited", business: true, counts_toward_524: true), # per-card override
      card("2025-06-01", business: true),       # business cards don't report
      card("2025-07-01", product: "capital_one_spark_cash", business: true) # Capital One business does
    ]
    f = RewardCard::FiveTwentyFour.new(cards, today: @today)

    assert_equal 6, f.count
    assert_not f.under?
    assert_equal Date.new(2026, 12, 4), f.under_on # second-oldest counted card (11/4/24) ages off after 25 months
    assert_equal 0, f.slots
  end

  test "under 5/24 reports slots and next drop" do
    f = RewardCard::FiveTwentyFour.new([ card("2025-01-08"), card("2025-10-24") ], today: @today)

    assert f.under?
    assert_equal 2, f.slots
    assert_equal Date.new(2027, 2, 8), f.next_drop_on
    assert_equal @today, f.under_on
  end

  test "per-card override beats the default" do
    f = RewardCard::FiveTwentyFour.new([ card("2025-01-08", business: true, counts_toward_524: true), card("2025-02-01", counts_toward_524: false) ], today: @today)

    assert_equal 1, f.count
  end

  private
    def card(opened, **attrs)
      @family.reward_cards.new({ holder: "A", name: "Card", issuer: "chase", opened_on: Date.parse(opened) }.merge(attrs)).tap(&:validate)
    end
end
