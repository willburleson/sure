require "test_helper"

class RewardCard::IssuerRulesTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @today = Date.new(2026, 11, 17)
  end

  test "five tiles for the major issuers" do
    assert_equal %w[capital_one chase citi bofa amex], tiles([]).map { |tile| tile.issuer.key }
    assert tiles([]).all? { |tile| tile.issuer.logo.present? }
  end

  test "chase is clear under 5/24 and waits on the oldest card once over" do
    under = tiles(cards(%w[2025-01-08 2025-02-06 2025-04-04 2025-12-24], "citi")).find { |tile| tile.issuer.key == "chase" }
    over = tiles(cards(%w[2025-01-08 2025-02-06 2025-04-04 2025-12-24 2026-03-01], "citi")).find { |tile| tile.issuer.key == "chase" }

    assert_not under.blocked?
    assert over.blocked?
    assert_equal Date.new(2027, 2, 8), over.next_on
  end

  test "capital one personal card spacing counts your last personal card" do
    recent = [ @family.reward_cards.new(holder: "A", name: "Venture", issuer: "capital_one", product: "capital_one_venture", opened_on: Date.new(2026, 10, 4)) ]
    tile = tiles(recent).find { |t| t.issuer.key == "capital_one" }

    assert tile.blocked?
    assert_equal Date.new(2026, 10, 4) + 182.days, tile.next_on
  end

  private
    def tiles(cards)
      RewardCard::IssuerRules.new(RewardCard::Eligibility.new(cards, today: @today)).tiles
    end

    def cards(dates, issuer)
      dates.map { |date| @family.reward_cards.new(holder: "A", name: "Card", issuer: issuer, opened_on: Date.parse(date)) }
    end
end
