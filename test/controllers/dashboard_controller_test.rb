require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = members(:alice)
    grant_membership_to(@member)
  end

  test "dashboard shows today's figures" do
    sell!(member: @member, product: products(:yoga_monthly), amount: 20, agreed_price: 20, start_date: Date.current - 20, end_date: Date.current + 3)
    AccessLog.create!(member: @member, discipline: disciplines(:yoga), checkin_by_user: users(:staff))
    sign_in_as(users(:staff))

    get root_path
    assert_response :success
    assert_equal 1, controller.instance_variable_get(:@today_accesses_count)
    assert_includes controller.instance_variable_get(:@expiring_subscriptions).map(&:member), @member
  end

  test "expiring subscriptions page linked from the dashboard renders" do
    sell!(member: @member, product: products(:yoga_monthly), start_date: Date.current - 20, end_date: Date.current + 3)
    sign_in_as(users(:staff))

    get subscriptions_path(filter: "expiring")
    assert_response :success
    assert_match "Abbonamenti in scadenza", response.body
    assert_match "Alice Allevi", response.body
  end

  test "expiring page excludes subscriptions beyond a week" do
    Subscription.where(member: @member).update_all(end_date: Date.current + 30)
    sign_in_as(users(:staff))

    get subscriptions_path(filter: "expiring")
    assert_no_match "Alice Allevi", response.body
  end
end
