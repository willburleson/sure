require "test_helper"

class RewardCard::RankingTest < ActiveSupport::TestCase
  Offers = Struct.new(:offers) do
    def offer(key) = offers[key]
  end

  setup do
    @family = families(:dylan_family)
    @today = Date.new(2026, 11, 17)
  end

  test "venture goes before venture x because a venture x bonus blocks venture" do
    ranking = ranking_for([], venture: offer("capital_one_venture", 75_000, "points"), venture_x: offer("capital_one_venture_x", 75_000, "points"))
    entries = ranking.groups.flat_map(&:entries).index_by { |entry| entry.product.key }

    assert_equal [ "capital_one_venture", "capital_one_venture_x" ], ranking.groups.flat_map(&:entries).map { |entry| entry.product.key }
    assert_equal [ "Capital One Venture X" ], entries["capital_one_venture"].before.map(&:name)
    assert_equal [ "Capital One Venture" ], entries["capital_one_venture_x"].after.map(&:name)
  end

  test "venture is told to go before venture x even when only venture has an offer" do
    ranking = ranking_for([], venture: offer("capital_one_venture", 75_000, "points"))
    entry = ranking.groups.flat_map(&:entries).first

    assert_equal [ "Capital One Venture X" ], entry.before.map(&:name)
  end

  test "higher bonus ranks first within a program even when that means waiting" do
    ranking = ranking_for([], venture: offer("capital_one_venture", 75_000, "points"), venture_x: offer("capital_one_venture_x", 100_000, "points"))

    assert_equal [ "capital_one_venture", "capital_one_venture_x" ], ranking.groups.flat_map(&:entries).map { |entry| entry.product.key }
  end

  test "cash offers count rakuten and other cash extras" do
    quiet = offer("citi_double_cash", 200, "cash")
    portal = offer("wells_fargo_active_cash", 200, "cash", extras: [ { "label" => "Rakuten", "amount" => 300, "unit" => "cash", "kind" => "portal" } ])
    ranking = ranking_for([], a: quiet, b: portal)

    assert_equal [ "wells_fargo_active_cash", "citi_double_cash" ], ranking.groups.flat_map(&:entries).map { |entry| entry.product.key }
    assert_equal 500, portal_offer(ranking).cash_total
  end

  test "chase goes before other issuers at 4/24" do
    cards = %w[2025-01-08 2025-02-06 2025-04-04 2025-12-24].map { |date| card(date, issuer: "citi") }
    ranking = ranking_for(cards, chase: offer("chase_freedom_flex", 200, "cash"), citi: offer("citi_double_cash", 300, "cash"))

    assert_equal [ "chase_freedom_flex", "citi_double_cash" ], ranking.groups.flat_map(&:entries).map { |entry| entry.product.key }
  end

  test "products you already hold or are not eligible for are left out" do
    held = [ card("2024-01-01", product: "citi_double_cash", issuer: "citi") ]
    ranking = ranking_for(held, a: offer("citi_double_cash", 200, "cash"))

    assert_not ranking.any?
  end

  private
    def offer(key, amount, unit, extras: [])
      RewardCard::Bonuses::Offer.new(
        product_key: key, amount: amount, unit: unit, spend: 4000, months: 3, fee: 95, note: nil,
        extras: extras.map { |extra| RewardCard::Bonuses::Extra.new(label: extra["label"], amount: extra["amount"], unit: extra["unit"], kind: extra["kind"]) }
      )
    end

    def ranking_for(cards, **offers)
      eligibility = RewardCard::Eligibility.new(cards, today: @today)
      RewardCard::Ranking.new(eligibility, bonuses: Offers.new(offers.values.index_by(&:product_key)))
    end

    def portal_offer(ranking)
      ranking.groups.flat_map(&:entries).map(&:offer).find { |offer| offer.extras.any? }
    end

    def card(opened, issuer:, product: nil)
      @family.reward_cards.new(holder: "A", name: "Card", issuer: issuer, product: product, opened_on: Date.parse(opened))
    end
end
