require "test_helper"

# lo storico abbonamenti del socio: periodo, pagamenti, rata da incassare, rinnovo e annullo
class Members::SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = members(:alice)
    grant_membership_to(@member)
    @sub = sell!(member: @member, product: products(:yoga_monthly), amount: 10).subscription
    sign_in_as(users(:staff))
  end

  def row(subscription = @sub) = "##{ActionView::RecordIdentifier.dom_id(subscription)}"

  test "a running subscription with a debt: days left, receipt, what is left to pay" do
    get member_subscriptions_path(@member)

    assert_select row, text: /gg rimasti/
    assert_select "#{row} a[href='#{sale_path(@sub.sales.first)}']", text: @sub.sales.first.receipt_code
    assert_select row, text: /Resta: 35,00/
    assert_select "#{row} a[href='#{new_sale_path(member_id: @member.id, installment_for_subscription_id: @sub.id)}']"
    assert_select "#{row}.grayscale", count: 0
  end

  test "an expired subscription is greyed out and offers the renewal until renewed" do
    @sub.update_columns(start_date: Date.current - 60, end_date: Date.current - 30)
    renew = "#{row} a[href='#{renew_sale_path(@sub)}']"

    get member_subscriptions_path(@member)
    assert_select "#{row}.grayscale"
    assert_select row, text: /gg rimasti/, count: 0
    assert_select renew

    Subscription.create!(member: @member, product: @sub.product, start_date: Date.current - 29, end_date: Date.current)
    get member_subscriptions_path(@member)
    assert_select renew, count: 0
  end

  test "a running subscription is not renewed from the history" do
    @sub.update_columns(start_date: Date.current - 1, end_date: Date.current + 60)
    get member_subscriptions_path(@member)
    assert_select "#{row} a[href='#{renew_sale_path(@sub)}']", count: 0
  end

  test "undo only for who can reverse every payment" do
    undo = "#{row} a[data-turbo-method=delete][href='#{subscription_path(@sub)}']"
    get member_subscriptions_path(@member)
    assert_select undo

    sign_in_as(users(:staff_two))
    get member_subscriptions_path(@member)
    assert_select undo, count: 0
  end

  private
    def renew_sale_path(subscription) = new_sale_path(sale: { member_id: subscription.member_id, product_id: subscription.product_id })
end
