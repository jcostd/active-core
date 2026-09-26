require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = members(:alice)
    grant_membership_to(@member)
  end

  test "dashboard shows today's figures" do
    sell!(member: @member, product: products(:yoga_monthly), amount: 20, agreed_price: 20, user: users(:admin), start_date: Date.current - 20, end_date: Date.current + 3)
    AccessLog.create!(member: @member, discipline: disciplines(:yoga), checkin_by_user: users(:staff))
    sign_in_as(users(:staff))

    get root_path
    assert_response :success
    assert_equal 1, controller.instance_variable_get(:@today_accesses_count)
    assert_includes controller.instance_variable_get(:@expiring_subscriptions).map(&:member), @member
  end

  test "expiring subscriptions page linked from the dashboard renders" do
    sell!(member: @member, product: products(:yoga_monthly), user: users(:admin), start_date: Date.current - 20, end_date: Date.current + 3)
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

  test "renewed subscriptions leave the expiring list" do
    course = link!(products(:yoga_monthly), disciplines(:yoga))
    Subscription.create!(member: @member, product: course, start_date: Date.current - 20, end_date: Date.current + 3)
    Subscription.where(member: @member).joins(:product).merge(Product.associative).update_all(end_date: Date.current + 200)
    sign_in_as(users(:staff))

    get root_path
    assert_equal 1, controller.instance_variable_get(:@expiring_count)

    Subscription.create!(member: @member, product: course, start_date: Date.current + 4, end_date: Date.current + 30)
    get root_path
    assert_equal 0, controller.instance_variable_get(:@expiring_count)

    get subscriptions_path(filter: "expiring")
    assert_no_match "Alice Allevi", response.body
  end
end
