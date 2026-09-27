require "test_helper"

class SubscriptionsHelperTest < ActionView::TestCase
  include IconsHelper, UiHelper, FormatHelper

  setup do
    @member = members(:alice)
    grant_membership_to(@member)
    @sub = sell!(member: @member, product: products(:yoga_monthly), amount: 10).subscription
  end

  def current_user = @current_user || users(:staff)

  test "every subscription status has a style" do
    %i[expired future expiring_soon active].each do |key|
      status = Struct.new(:key, :label).new(key, "x")
      assert subscription_status_badge(status).present?, key
    end
  end

  test "status badge shows the period with literal classes, never the payment" do
    @sub.update_columns(start_date: Date.current - 1, end_date: Date.current + 20)
    html = subscription_status_badge(@sub.reload.status)
    assert_match "Attivo", html
    assert_match "badge-success", html
    assert_no_match "saldare", html
    assert_match 'class="p-2 rounded-box bg-success/10 text-success"', subscription_status_icon(@sub.status)
  end

  test "payment badge shows what is due while running" do
    @sub.update_columns(start_date: Date.current - 1, end_date: Date.current + 20)
    html = subscription_payment_badge(@sub.reload)
    assert_match "Da saldare #{format_cents(@sub.amount_due)}", html
    assert_match "badge-warning", html
  end

  test "payment badge calls an expired debt insoluto" do
    @sub.update_columns(start_date: Date.current - 60, end_date: Date.current - 30)
    html = subscription_payment_badge(@sub.reload)
    assert_match "Insoluto #{format_cents(@sub.amount_due)}", html
    assert_match "badge-error", html
  end

  test "payment badge for paid and free subscriptions" do
    @sub.update_columns(agreed_price_cents: 1000)
    assert_match "Saldato", subscription_payment_badge(@sub.reload)
    assert_no_match "€", subscription_payment_badge(@sub)

    @sub.update_columns(agreed_price_cents: 0)
    assert_nil subscription_payment_badge(@sub.reload)
  end

  test "installment action only when something is due" do
    assert_match "Resta: 35,00", subscription_installment_action(@sub, @sub.amount_due)
    assert_match "installment_for_subscription_id=#{@sub.id}", subscription_installment_action(@sub, 1)
    assert_nil subscription_installment_action(@sub, 0)
  end

  test "renew action for expired or expiring only" do
    expiring = Struct.new(:key).new(:expiring_soon)
    active   = Struct.new(:key).new(:active)

    assert_match CGI.escape("sale[product_id]") + "=#{@sub.product_id}", subscription_renew_action(@sub, expiring)
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
