require "test_helper"

class RewardCard::EligibilityTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @today = Date.new(2026, 11, 17)
  end

  test "citi product bonus is 48 months from the last bonus" do
    result = result_for("citi_strata_premier", [ card("citi_strata_premier", "2022-07-31", closed_on: "2023-09-14") ])

    assert_equal Date.new(2026, 10, 31), result.eligible_on
    assert_equal :eligible, result.status
    assert result.newly_eligible?
    assert result.alert?
  end

  test "upcoming when a dated rule clears within 90 days" do
    result = result_for("citi_strata_premier", [ card("citi_strata_premier", "2022-10-01", bonus_received_on: "2022-12-20", closed_on: "2024-01-01") ])

    assert_equal :upcoming, result.status
    assert_equal Date.new(2026, 12, 20), result.eligible_on
  end

  test "chase is blocked until under 5/24" do
    cards = %w[2025-01-08 2025-02-06 2025-04-04 2025-10-24 2026-03-01].map { |date| card(nil, date, issuer: "citi") }
    result = result_for("chase_sapphire_reserve", cards)

    assert_equal Date.new(2027, 1, 8), result.eligible_on
    assert_equal :upcoming, result.status
  end

  test "sapphire: close the card first, and the product bonus is once per lifetime" do
    holding = result_for("chase_sapphire_preferred", [ card("chase_sapphire_preferred", "2021-04-25", issuer: "chase") ])
    other = result_for("chase_sapphire_reserve", [ card("chase_sapphire_preferred", "2021-04-25", issuer: "chase") ])

    assert_equal :never, holding.status
    assert_equal :eligible, other.status
  end

  test "amex family rule blocks gold after platinum" do
    result = result_for("amex_gold", [ card("amex_platinum", "2017-04-25", issuer: "amex", closed_on: "2018-05-14") ])

    assert_equal :never, result.status
  end

  test "velocity rules use the card that drops off" do
    cards = [ card(nil, "2026-10-01", issuer: "citi"), card(nil, "2026-11-10", issuer: "citi") ]
    result = result_for("citi_custom_cash", cards)

    # 2/65: the October card ages out 65 days after opening.
    assert_equal Date.new(2026, 10, 1) + 65.days, result.eligible_on
  end

  test "bofa blocks while holding the product" do
    result = result_for("bofa_premium_rewards", [ card("bofa_premium_rewards", "2020-01-01", issuer: "bofa") ])

    assert_equal :close_first, result.status
  end

  private
    def result_for(product, cards)
      RewardCard::Eligibility.new(cards, today: @today).result_for(RewardCard::Catalog.product(product))
    end

    def card(product, opened, issuer: nil, closed_on: nil, **attrs)
      issuer ||= RewardCard::Catalog.product(product).issuer
      @family.reward_cards.new({
        holder: "A", name: "Card", issuer: issuer, product: product, opened_on: Date.parse(opened),
        closed_on: closed_on && Date.parse(closed_on), closed: closed_on.present?
      }.merge(attrs.transform_values { |v| v.is_a?(String) && v.match?(/\A\d{4}-/) ? Date.parse(v) : v }))
    end
end
