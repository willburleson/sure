require "test_helper"

class PointBalance::EstimatorTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @account = accounts(:credit_card)
    @account.entries.destroy_all
    @today = Date.current
  end

  test "adds earn since the last balance at category rates" do
    @family.reward_cards.create!(holder: "A", product: "chase_sapphire_preferred", issuer: "chase", opened_on: 1.year.ago.to_date, account: @account)
    @family.point_balances.create!(holder: "A", program: "chase_ur", balance: 1000, as_of: @today - 10.days)

    create_transaction(account: @account, date: @today - 20.days, amount: 500)                                    # before balance: ignored
    create_transaction(account: @account, date: @today - 5.days, amount: 100)                                     # 1x
    create_transaction(account: @account, date: @today - 4.days, amount: 50, category: categories(:subcategory)) # Restaurants: 3x
    create_transaction(account: @account, date: @today - 3.days, amount: -20)                                     # refund: -1x
    create_transaction(account: @account, date: @today - 2.days, amount: 300, kind: "cc_payment")                # payment: ignored

    estimate = PointBalance::Estimator.new(@family, today: @today).estimates_for("A").sole

    assert_equal 230, estimate.earned
    assert_equal 1230, estimate.total
    assert_equal 3, estimate.transaction_count
  end

  test "cash programs earn percent" do
    @family.reward_cards.create!(holder: "A", product: "capital_one_spark_cash", issuer: "capital_one", opened_on: 1.year.ago.to_date, account: @account)
    @family.point_balances.create!(holder: "A", program: "capital_one_cash", balance: 80.23, as_of: @today - 10.days)
    create_transaction(account: @account, date: @today - 1.day, amount: 1000)

    estimate = PointBalance::Estimator.new(@family, today: @today).estimates_for("A").sole

    assert_equal BigDecimal("20"), estimate.earned
    assert_equal BigDecimal("100.23"), estimate.total
  end

  test "latest balance wins" do
    @family.point_balances.create!(holder: "A", program: "delta", balance: 10, as_of: @today - 10.days)
    @family.point_balances.create!(holder: "A", program: "delta", balance: 20, as_of: @today - 1.day)

    assert_equal 20, PointBalance::Estimator.new(@family, today: @today).estimates_for("A").sole.total
  end
end
