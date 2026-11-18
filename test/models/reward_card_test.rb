require "test_helper"

class RewardCardTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
  end

  test "display name prefers the catalog card over the sheet label" do
    card = @family.reward_cards.new(holder: "A", product: "wells_fargo_autograph_journey", name: "Wells Fargo", issuer: "wells_fargo", opened_on: Date.new(2025, 4, 4))

    assert_equal "Wells Fargo Autograph Journey", card.display_name
    assert_equal "Wells Fargo", card.nickname
  end

  test "generic cards keep their typed name and ask for the real card" do
    card = @family.reward_cards.new(holder: "A", product: "chase_other", name: "Chase", issuer: "chase", opened_on: Date.new(2016, 9, 1), closed: true)

    assert_equal "Chase", card.display_name
    assert_nil card.nickname
    assert_equal %i[close_date product], card.missing_details
  end

  test "held months stop at the close date" do
    card = @family.reward_cards.new(holder: "A", product: "amex_gold", issuer: "amex", opened_on: Date.new(2015, 3, 18), closed: true, closed_on: Date.new(2016, 5, 7))
    undated = @family.reward_cards.new(holder: "A", product: "amex_gold", issuer: "amex", opened_on: Date.new(2015, 3, 18), closed: true)

    assert_equal 13, card.held_months(Date.new(2026, 11, 17))
    assert_nil undated.held_months(Date.new(2026, 11, 17))
  end

  test "bonus date is flagged as estimated when not entered" do
    card = @family.reward_cards.new(holder: "A", product: "amex_gold", issuer: "amex", opened_on: Date.new(2025, 1, 1))

    assert card.bonus_estimated?
    assert_equal Date.new(2025, 4, 1), card.bonus_on
  end
end
