require "test_helper"

class SubscriptionsHelperTest < ActionView::TestCase
  include IconsHelper, UiHelper, FormatHelper

  setup do
    @member = members(:alice)
    grant_membership_to(@member)
    @sub = sell!(member: @member, product: products(:yoga_monthly), amount: 10).subscription
  end

  test "every subscription status has a style" do
    assert_equal Subscription::STATUS_LABELS.keys.sort, SUBSCRIPTION_STATUS_STYLES.keys.sort
    assert_equal Subscription::PAYMENT_LABELS.keys.sort, SUBSCRIPTION_PAYMENT_STYLES.keys.sort
  end

  test "status badge shows the period with literal classes, never the payment" do
    @sub.update_columns(start_date: Date.current - 1, end_date: Date.current + 20)
    html = subscription_status_badge(@sub.reload)
    assert_match "Attivo", html
    assert_match "badge-success", html
    assert_no_match "saldare", html
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
end
