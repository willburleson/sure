require "test_helper"

class Settings::AppearancesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    sign_in @user
  end

  test "renders the account group order list" do
    get settings_appearance_url

    assert_response :success
    assert_select "[data-controller='account-group-order']", count: 1
    assert_select "input[name='user[account_group_order][]']", count: Accountable::TYPES.size
  end

  test "saves account group order, dropping unknown and repeated keys" do
    patch settings_appearance_url, params: { user: { account_group_order: %w[investment depository bogus investment] } }

    assert_redirected_to settings_appearance_url
    assert_equal %w[investment depository], @user.reload.preferences["account_group_order"]
  end

  test "omitting account group order keeps the stored order" do
    @user.update!(preferences: (@user.preferences || {}).merge("account_group_order" => %w[crypto]))

    patch settings_appearance_url, params: { user: { dashboard_two_column: "1" } }

    assert_equal %w[crypto], @user.reload.preferences["account_group_order"]
  end
end
