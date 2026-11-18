require "test_helper"

class RewardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @family = @user.family
  end

  test "empty state" do
    get rewards_url
    assert_response :success
  end

  test "shows holders, cards, eligibility and points" do
    @family.reward_cards.create!(holder: "Pat", product: "capital_one_venture_x", issuer: "capital_one", opened_on: Date.new(2021, 11, 11), account: accounts(:credit_card))
    @family.reward_cards.create!(holder: "Sam", product: "chase_ink_premier", issuer: "chase", opened_on: Date.new(2026, 3, 17))
    @family.point_balances.create!(holder: "Pat", program: "capital_one", balance: 140_251, as_of: 1.month.ago.to_date)

    get rewards_url(holder: "Pat")
    assert_response :success
    assert_select "a", text: "Sam"
    assert_select "li a", text: /140,251 on/
    assert_select "th button[data-action=\"table-sort#sort\"]", minimum: 4
    assert_select ".line-through", count: 0
    assert_select "summary", text: /Capital One Venture X/

    get root_url
    assert_response :success
    assert_select "#rewards-summary"
  end

  test "creates, updates and deletes a card" do
    assert_difference -> { @family.reward_cards.count } do
      post reward_cards_url, params: { reward_card: { holder: "Pat", product: "citi_strata_elite", opened_on: "2025-10-24", counts_toward_524: "" } }
    end
    card = @family.reward_cards.last
    assert_equal "citi", card.issuer
    assert_equal "Citi Strata Elite", card.name
    assert_nil card.counts_toward_524

    patch reward_card_url(card), params: { reward_card: { closed_on: "2026-11-01" } }
    assert card.reload.closed?

    get edit_reward_card_url(card)
    assert_response :success

    assert_difference -> { @family.reward_cards.count }, -1 do
      delete reward_card_url(card)
    end
  end

  test "rejects another family's account" do
    other = accounts(:credit_card).dup.tap { |a| a.family = families(:empty) }
    other.save!(validate: false)

    post reward_cards_url, params: { reward_card: { holder: "Pat", product: "citi_strata_elite", opened_on: "2025-10-24", account_id: other.id } }
    assert_response :not_found
  end

  test "records a balance from the dashboard" do
    assert_difference -> { @family.point_balances.count } do
      post point_balances_url, params: { point_balance: { holder: "Pat", program: "chase_ur", balance: "120,491" } }, headers: { "HTTP_REFERER" => root_url }
    end
    assert_redirected_to root_url
    balance = @family.point_balances.last
    assert_equal 120_491, balance.balance
    assert_equal Date.current, balance.as_of

    get point_balances_url(holder: "Pat", program: "chase_ur")
    assert_response :success

    assert_difference -> { @family.point_balances.count }, -1 do
      delete point_balance_url(balance)
    end
  end
end
