require "test_helper"

class AccountsHelperTest < ActionView::TestCase
  setup do
    @user = users(:family_admin)
    Current.stubs(:user).returns(@user)
  end

  test "sidebar cache key changes when the account group order changes" do
    before = account_sidebar_tabs_cache_key(family: @user.family, active_tab: "all", mobile: false)

    @user.update!(preferences: (@user.preferences || {}).merge("account_group_order" => %w[credit_card depository]))

    after = account_sidebar_tabs_cache_key(family: @user.family, active_tab: "all", mobile: false)
    assert_not_equal before, after
  end
end
