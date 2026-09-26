require "test_helper"

class SubscriptionsHelperTest < ActionView::TestCase
  include IconsHelper, UiHelper, FormatHelper

  setup do
    @member = members(:alice)
    grant_membership_to(@member)
    @sub = sell!(member: @member, product: products(:yoga_monthly), amount: 10).subscription
  end

  def current_user = @current_user || users(:staff)

  test "labels and icons with fallback" do
    assert_equal "Da Saldare", subscription_status_label(:pending_payment)
    assert_equal "Weird", subscription_status_label(:weird)
    assert_equal "help", subscription_status_icon(:weird)
  end

  test "payment badge" do
    assert_match "Da saldare", subscription_payment_badge(@sub, @sub.amount_due)
    assert_match "Saldato", subscription_payment_badge(@sub, 0)

    @sub.agreed_price_cents = 0
    assert_nil subscription_payment_badge(@sub, 0)
  end

  test "installment action only when something is due" do
    assert_match "Resta: 35,00", subscription_installment_action(@sub, @sub.amount_due)
    assert_match "installment_for_subscription_id=#{@sub.id}", subscription_installment_action(@sub, 1)
    assert_nil subscription_installment_action(@sub, 0)
  end

  test "renew action for expired or expiring only" do
    expiring = Struct.new(:key).new(:expiring_soon)
    active   = Struct.new(:key).new(:active)

    assert_match "renew_subscription_id=#{@sub.id}", subscription_renew_action(@sub, expiring)
    assert_nil subscription_renew_action(@sub, active)
  end

  test "days left hidden for expired" do
    assert_match "gg rimasti", subscription_days_left_indicator(@sub, @sub.status)
    assert_nil subscription_days_left_indicator(@sub, Struct.new(:key).new(:expired))
  end

  test "archive action follows discardable_by?" do
    assert_match 'data-turbo-method="delete"', subscription_archive_action(@sub)

    @current_user = users(:staff_two)
    assert_nil subscription_archive_action(@sub)
  end

  test "row wrapper greys out expired" do
    html = subscription_row_wrapper(@sub, Struct.new(:key).new(:expired)) { "x" }
    assert_match "grayscale", html
    assert_match ActionView::RecordIdentifier.dom_id(@sub), html
  end

  test "receipt link only for receipts" do
    assert_match @sub.sales.first.receipt_code, subscription_sale_receipt_link(@sub.sales.first)
    assert_nil subscription_sale_receipt_link(Sale.new)
  end

  test "renew action hidden once renewed" do
    expiring = Struct.new(:key).new(:expiring_soon)
    Subscription.create!(member: @member, product: @sub.product, start_date: @sub.end_date + 1, end_date: @sub.end_date + 30)

    assert_nil subscription_renew_action(@sub, expiring)
  end
end
