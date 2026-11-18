require "test_helper"

class RewardCard::RankingTest < ActiveSupport::TestCase
  Offers = Struct.new(:offers) do
    def offer(key) = offers[key]
  end

  setup do
    @family = families(:dylan_family)
    @today = Date.new(2026, 11, 17)
  end

  test "venture goes before venture x: a venture x bonus blocks venture for 48 months, venture only delays x by 6" do
    ranking = ranking_for([], venture: offer("capital_one_venture", 75_000, "points"), venture_x: offer("capital_one_venture_x", 75_000, "points"))
    entries = ranking.list.index_by { |entry| entry.product.key }

    assert_equal [ "capital_one_venture", "capital_one_venture_x" ], ranking.list.map { |entry| entry.product.key }
    assert_equal [ "Capital One Venture X" ], entries["capital_one_venture"].before.map { |delay| delay.product.name }
    assert_equal [ "Capital One Venture" ], entries["capital_one_venture_x"].after.map { |delay| delay.product.name }
    assert_operator entries["capital_one_venture"].before.first.until, :>, @today + 4.years - 1.month
  end

  test "venture goes before venture x even when x is worth more, and when only venture has an offer" do
    both = ranking_for([], venture: offer("capital_one_venture", 75_000, "points"), venture_x: offer("capital_one_venture_x", 100_000, "points"))
    only = ranking_for([], venture: offer("capital_one_venture", 75_000, "points"))

    assert_equal [ "capital_one_venture", "capital_one_venture_x" ], both.list.map { |entry| entry.product.key }
    assert_equal [ "Capital One Venture X" ], only.list.first.before.map { |delay| delay.product.name }
  end

  test "one list across programs, best first by first-year worth, rakuten included" do
    portal = offer("chase_ink_premier", 200, "cash", extras: [ { "label" => "Rakuten", "amount" => 300, "unit" => "cash", "kind" => "portal" } ])
    big = offer("amex_platinum", 175_000, "points", value: 3_500, fee: 895)
    small = offer("capital_one_savor", 250, "cash", fee: 0)
    ranking = ranking_for([], a: small, b: portal, c: big)

    assert_equal 500, portal.cash_total
    assert_equal [ "amex_platinum", "chase_ink_premier", "capital_one_savor" ], ranking.list.map { |entry| entry.product.key }
  end

  test "annual fee comes off the worth" do
    cheap = offer("capital_one_savor", 250, "cash", fee: 0)
    pricey = offer("chase_ink_premier", 300, "cash", fee: 150)

    assert_equal [ "capital_one_savor", "chase_ink_premier" ], ranking_for([], a: cheap, b: pricey).list.map { |entry| entry.product.key }
  end

  test "chase goes before other issuers at 4/24 even when worth less" do
    cards = %w[2025-01-08 2025-02-06 2025-04-04 2025-12-24].map { |date| card(date, issuer: "citi") }
    ranking = ranking_for(cards, chase: offer("chase_freedom_flex", 200, "cash"), savor: offer("capital_one_savor", 250, "cash"))
    entries = ranking.list.index_by { |entry| entry.product.key }

    assert_equal [ "chase_freedom_flex", "capital_one_savor" ], ranking.list.map { |entry| entry.product.key }
    assert_includes entries["chase_freedom_flex"].before.map { |delay| delay.product.name }, "Capital One Savor"
    assert_equal [ "Chase Freedom Flex" ], entries["capital_one_savor"].after.map { |delay| delay.product.name }
  end

  test "cards you already hold are left out" do
    held = [ card("2024-01-01", product: "chase_freedom_flex", issuer: "chase") ]
    ranking = ranking_for(held, flex: offer("chase_freedom_flex", 200, "cash"))

    assert_not ranking.any?
  end

  private
    def offer(key, amount, unit, extras: [], value: nil, fee: 95)
      RewardCard::Bonuses::Offer.new(
        product_key: key, amount: amount, unit: unit, spend: 4000, months: 3, fee: fee, note: nil, value: value, value_note: nil,
        extras: extras.map { |extra| RewardCard::Bonuses::Extra.new(label: extra["label"], amount: extra["amount"], unit: extra["unit"], kind: extra["kind"]) }
      )
    end

    def ranking_for(cards, **offers)
      eligibility = RewardCard::Eligibility.new(cards, today: @today)
      RewardCard::Ranking.new(eligibility, bonuses: Offers.new(offers.values.index_by(&:product_key)))
    end

    def card(opened, issuer:, product: nil)
      @family.reward_cards.new(holder: "A", name: "Card", issuer: issuer, product: product, opened_on: Date.parse(opened))
    end
end
