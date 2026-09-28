require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = members(:alice)
    grant_membership_to(@member)
  end

  test "dashboard shows today's figures" do
    sell!(member: @member, product: products(:yoga_monthly), amount: 20, agreed_price: 20, user: users(:admin), start_date: Date.current - 20, end_date: Date.current + 3)
    sign_in_as(users(:staff))

    get root_path
    assert_response :success
    assert_includes controller.instance_variable_get(:@expiring_subscriptions).map(&:member), @member
  end

  test "dashboard lists who attends this month without a subscription" do
    yoga, pesi = disciplines(:yoga), disciplines(:sala_pesi)
    course = link!(products(:yoga_monthly), yoga)
    Subscription.create!(member: @member, product: course, start_date: Date.current.beginning_of_month, end_date: Date.current.end_of_month)
    Attendance.create!(member: @member, discipline: yoga, marked_by: users(:kiosk))           # iscritta: niente da fare
    Attendance.create!(member: @member, discipline: pesi, marked_by: users(:kiosk))           # frequenta pesi senza abbonamento
    Attendance.create!(member: members(:bob), discipline: yoga, month: Date.current.prev_month, marked_by: users(:admin)) # mese scorso
    archived = Member.create!(first_name: "Ex", last_name: "Socio", birth_date: 40.years.ago, fiscal_code_pending: true)
    Attendance.create!(member: archived, discipline: yoga, marked_by: users(:kiosk))
    archived.discard!
    sign_in_as(users(:staff))

    get root_path
    assert_select ".stat", text: /Da regolarizzare\s*1/
    assert_select "#unenrolled_attendances li", count: 1
    assert_select "#unenrolled_attendances li", text: /Alice Allevi\s*Sala Pesi/
    assert_select "#unenrolled_attendances a[href='#{new_sale_path(member_id: @member.id)}'][data-turbo-frame=modal]"
    assert_select "#unenrolled_attendances a[href='#{discipline_members_path(pesi)}']"
  end

  test "dashboard with nobody to regularize" do
    sign_in_as(users(:staff))

    get root_path
    assert_select ".stat", text: /Da regolarizzare\s*0/
    assert_select "#unenrolled_attendances", text: /nessuno da regolarizzare/
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
