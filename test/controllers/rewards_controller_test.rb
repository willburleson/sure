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
    assert_select "li a", text: /140,251 on/, count: 0   # points live on the Household tab
    assert_select "th button[data-action=\"table-sort#sort\"]", minimum: 4
    assert_select ".line-through", count: 0
    assert_select "summary", text: /Capital One Venture X/

    assert_select "span", text: "You have this"
    assert_select "#coming-up"

    # Open cards tile jumps to the list; Show closed swaps inside a frame instead of reloading the page.
    assert_select "a[href=\"#open-cards\"]"
    assert_select "turbo-frame#card-history #open-cards"

    # Issuer rules tiles, with logos.
    assert_select "section h2", text: "Issuer rules"
    assert_select "details summary img[alt=\"Chase\"]"
    assert_select "details summary p", text: "Capital One"

    get root_url
    assert_response :success
    assert_select "#rewards-summary"
  end

  test "household tab sums balances across holders" do
    @family.reward_cards.create!(holder: "Pat", product: "capital_one_venture_x", issuer: "capital_one", opened_on: Date.new(2021, 11, 11))
    @family.reward_cards.create!(holder: "Sam", product: "capital_one_venture", issuer: "capital_one", opened_on: Date.new(2021, 7, 20))
    @family.point_balances.create!(holder: "Pat", program: "capital_one", balance: 1_000, as_of: Date.current)
    @family.point_balances.create!(holder: "Sam", program: "capital_one", balance: 500, as_of: Date.current)

    get rewards_url(holder: "household")
    assert_response :success
    assert_select "p", text: "1,500"
    assert_select "h3", text: "Pat"
    assert_select "h3", text: "Sam"
  end

  test "closed cards are hidden until asked for, and cards missing details are listed" do
    @family.reward_cards.create!(holder: "Pat", product: "capital_one_venture_x", issuer: "capital_one", opened_on: Date.new(2021, 11, 11))
    @family.reward_cards.create!(holder: "Pat", product: "chase_other", name: "Old Chase", issuer: "chase", opened_on: Date.new(2016, 9, 1), closed: true)

    get rewards_url(holder: "Pat")
    assert_select "tbody a", text: "Old Chase", count: 0
    assert_select "turbo-frame#card-history a", text: "Show 1 closed"
    assert_select "details h2", text: /1 card needs details/

    get rewards_url(holder: "Pat", closed: "1")
    assert_select "tbody a", text: "Old Chase"
  end

  test "turning closed off reopens a card and clears its close date" do
    card = @family.reward_cards.create!(holder: "Pat", product: "citi_strata_elite", issuer: "citi", opened_on: Date.new(2025, 10, 24), closed_on: Date.new(2026, 1, 1), closed: true)

    patch reward_card_url(card), params: { reward_card: { closed: "0", closed_on: "2026-01-01" } }
    card.reload
    assert card.open?
    assert_nil card.closed_on

    patch reward_card_url(card), params: { reward_card: { closed: "0", closed_on: "2026-02-01" } }
    assert card.reload.closed?
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
