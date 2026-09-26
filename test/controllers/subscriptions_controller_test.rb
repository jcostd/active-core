require "test_helper"

class SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = members(:alice)
    grant_membership_to(@member)
    @sub = sell!(member: @member, product: products(:yoga_monthly)).subscription
    sign_in_as(users(:admin))
  end

  test "admin edits dates" do
    get edit_subscription_path(@sub)
    assert_response :success

    patch subscription_path(@sub), params: { subscription: { end_date: (@sub.end_date + 5).iso8601 } }
    assert_redirected_to member_subscriptions_path(@member)
    assert_equal @sub.end_date + 5, @sub.reload.end_date
  end

  test "invalid dates re-render" do
    patch subscription_path(@sub), params: { subscription: { end_date: (@sub.start_date - 1).iso8601 } }
    assert_response :unprocessable_entity
  end

  test "agreed price cannot be changed from the edit form" do
    patch subscription_path(@sub), params: { subscription: { agreed_price_cents: 1 } }
    assert_equal products(:yoga_monthly).price_cents, @sub.reload.agreed_price_cents
  end
end
