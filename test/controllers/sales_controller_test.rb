require "test_helper"

class SalesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @staff  = users(:staff)
    @admin  = users(:admin)
    @member = members(:bob)
    @course = products(:yoga_monthly)

    grant_membership_to(@member)
    @sale = Sale.create!(member: @member, product: @course, user: @staff, sold_on: Date.current,
                         amount: 10, subscription_attributes: { member: @member, product: @course })
  end

  test "staff cannot reverse a sale" do
    sign_in_as(@staff)

    delete sale_path(@sale)

    assert_redirected_to root_path
    assert @sale.reload.kept?
  end

  test "admin reverses a recent sale" do
    sign_in_as(@admin)

    delete sale_path(@sale)

    assert @sale.reload.discarded?
  end

  test "admin cannot reverse after the window" do
    travel_to (Sale::REVERSAL_WINDOW + 1.minute).from_now do
      sign_in_as(@admin)

      delete sale_path(@sale)

      assert @sale.reload.kept?
    end
  end

  test "staff cashes an arbitrary installment" do
    sign_in_as(@staff)
    sub = @sale.subscription

    assert_difference -> { Sale.count } do
      post sales_path, params: { sale: { member_id: @member.id, product_id: @course.id, subscription_id: sub.id,
                                         amount: "7,50", payment_method: "cash", sold_on: Date.current } }
    end
    assert_equal 4500 - 1000 - 750, sub.reload.amount_due
  end

  test "staff agreed price is ignored" do
    sign_in_as(@staff)
    alice = members(:alice)
    grant_membership_to(alice)

    post sales_path, params: { sale: { member_id: alice.id, product_id: @course.id, amount: "5", payment_method: "cash",
                                       sold_on: Date.current, subscription_attributes: { start_date: Date.current, agreed_price: "0" } } }

    assert_response :redirect
    assert_equal @course.price_cents, Sale.last.subscription.agreed_price_cents
  end

  test "staff cannot discard a subscription" do
    sign_in_as(@staff)

    delete subscription_path(@sale.subscription)

    assert_redirected_to root_path
    assert @sale.subscription.reload.kept?
  end

  test "admin zero draft is kept by the POS builder" do
    sign_in_as(@admin)
    alice = members(:alice)

    get new_sale_path, params: { sale: { member_id: alice.id, product_id: @course.id, amount: "0",
                                         subscription_attributes: { agreed_price: "0" } },
                                 previous_member_id: alice.id, previous_product_id: @course.id }

    assert_response :success
    assert_select "input[name='sale[amount]'][value='0.0']"
  end
end
