require "test_helper"

# matrice dei permessi staff/admin, applicata lato server
class AuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @staff      = users(:staff)
    @admin      = users(:admin)
    @member     = members(:alice)
    @discipline = disciplines(:yoga)
    @product    = products(:yoga_monthly)
  end

  STAFF_ALLOWED = {
    "dashboard"          => ->(t) { t.get t.root_path },
    "members index"      => ->(t) { t.get t.members_path },
    "member show"        => ->(t) { t.get t.member_path(t.members(:alice)) },
    "member new"         => ->(t) { t.get t.new_member_path },
    "member edit"        => ->(t) { t.get t.edit_member_path(t.members(:alice)) },
    "member subs"        => ->(t) { t.get t.member_subscriptions_path(t.members(:alice)) },
    "member attendances" => ->(t) { t.get t.member_attendances_path(t.members(:alice)) },
    "disciplines index"  => ->(t) { t.get t.disciplines_path },
    "discipline show"    => ->(t) { t.get t.discipline_path(t.disciplines(:yoga)) },
    "discipline members" => ->(t) { t.get t.discipline_members_path(t.disciplines(:yoga)) },
    "new sale"           => ->(t) { t.get t.new_sale_path },
    "own profile"        => ->(t) { t.get t.user_path(t.users(:staff)) },
    "kiosk"              => ->(t) { t.get t.kiosk_root_path }
  }

  ADMIN_ONLY = {
    "member destroy"     => ->(t) { t.delete t.member_path(t.members(:alice)) },
    "member sales"       => ->(t) { t.get t.member_sales_path(t.members(:alice)) },
    "discipline new"     => ->(t) { t.get t.new_discipline_path },
    "discipline create"  => ->(t) { t.post t.disciplines_path, params: { discipline: { name: "Boxe" } } },
    "discipline edit"    => ->(t) { t.get t.edit_discipline_path(t.disciplines(:yoga)) },
    "discipline update"  => ->(t) { t.patch t.discipline_path(t.disciplines(:yoga)), params: { discipline: { name: "X" } } },
    "discipline destroy" => ->(t) { t.delete t.discipline_path(t.disciplines(:yoga)) },
    "reports index"      => ->(t) { t.get t.reports_path },
    "report show"        => ->(t) { t.get t.report_path("daily_cash") },
    "products index"     => ->(t) { t.get t.products_path },
    "sales index"        => ->(t) { t.get t.sales_path },
    "users index"        => ->(t) { t.get t.users_path },
    "gym profile show"   => ->(t) { t.get t.gym_profile_path },
    "gym profile edit"   => ->(t) { t.get t.edit_gym_profile_path },
    "gym profile update" => ->(t) { t.patch t.gym_profile_path, params: { gym_profile: { name: "Presa" } } }
  }

  STAFF_ALLOWED.each do |name, action|
    test "staff can reach #{name}" do
      sign_in_as(@staff)
      action.(self)
      assert_response :success
    end
  end

  ADMIN_ONLY.each do |name, action|
    test "staff is denied #{name}" do
      sign_in_as(@staff)
      action.(self)
      assert_redirected_to root_path
      assert_equal "Non disponi dei permessi necessari per accedere a questa sezione.", flash[:alert]
    end

    test "admin can reach #{name}" do
      sign_in_as(@admin)
      action.(self)
      assert_not_equal root_url, response.location if response.redirect?
      assert_nil flash[:alert]
    end
  end

  # l'utente kiosk non vede nulla fuori dal kiosk, nemmeno ciò che è concesso allo staff
  STAFF_ALLOWED.merge(ADMIN_ONLY).except("kiosk").merge(
    "sale receipt"   => ->(t) { t.get t.sale_path(t.sell!(member: t.members(:alice), product: t.products(:annual_membership)), format: :pdf) },
    "sale create"    => ->(t) { t.post t.sales_path, params: { sale: { member_id: t.members(:alice).id, product_id: t.products(:annual_membership).id } } },
    "member search"  => ->(t) { t.get t.members_searches_path(query: "Alice") },
    "user edit"      => ->(t) { t.get t.edit_user_path(t.users(:kiosk)) },
    "theme update"   => ->(t) { t.patch t.preferences_theme_path, params: { theme: "dark" } },
    "feedback new"   => ->(t) { t.get t.new_feedback_path },
    "desk marks"     => ->(t) { t.post t.discipline_attendances_path(t.disciplines(:yoga)), params: { member_id: t.members(:alice).id } }
  ).each do |name, action|
    test "kiosk user is confined away from #{name}" do
      sign_in_as(users(:kiosk))
      action.(self)
      assert_redirected_to kiosk_root_path
    end
  end

  test "kiosk user denied actions leave data untouched" do
    sign_in_as(users(:kiosk))

    assert_no_difference -> { Sale.count } do
      post sales_path, params: { sale: { member_id: @member.id, product_id: products(:annual_membership).id } }
    end
    delete member_path(@member)
    patch member_path(@member), params: { member: { first_name: "Hacked" } }

    assert @member.reload.kept?
    assert_equal "Alice", @member.first_name
  end

  test "kiosk user uses the whole kiosk" do
    sign_in_as(users(:kiosk))
    link!(@product, @discipline)

    get kiosk_root_path
    assert_response :success
    get kiosk_discipline_path(@discipline)
    assert_response :success
    get kiosk_discipline_member_searches_path(@discipline, query: "Ali")
    assert_response :success

    assert_difference -> { Attendance.count } do
      post kiosk_discipline_attendances_path(@discipline, member_id: @member.id)
    end
    assert_redirected_to kiosk_discipline_path(@discipline)
    assert_equal users(:kiosk), Attendance.last.marked_by

    assert_difference -> { Attendance.count }, -1 do
      delete kiosk_discipline_attendance_path(@discipline, Attendance.last)
    end
  end

  test "staff opens the kiosk and marks in their own name" do
    sign_in_as(@staff)

    post kiosk_discipline_attendances_path(@discipline, member_id: @member.id)
    assert_equal @staff, Attendance.last.marked_by
  end

  test "kiosk user can sign out" do
    sign_in_as(users(:kiosk))
    session = Current.session

    delete session_path
    assert_redirected_to new_session_path
    assert_not Session.exists?(session.id)
  end

  test "kiosk user lands on the kiosk after login, whatever was requested" do
    get members_path
    post session_path, params: { username: "kiosk", password: "password" }

    assert_redirected_to kiosk_root_url
  end

  test "staff still lands where they were going after login" do
    get members_path
    post session_path, params: { username: "staff", password: "password" }

    assert_redirected_to members_url
  end

  test "staff update of member is allowed" do
    sign_in_as(@staff)
    patch member_path(@member), params: { member: { phone: "3339998877" } }
    assert_equal "+393339998877", @member.reload.phone.then { Phonelib.parse(it, "IT").e164 }
  end

  test "staff denied actions leave data untouched" do
    sign_in_as(@staff)

    delete member_path(@member)
    delete discipline_path(@discipline)
    patch discipline_path(@discipline), params: { discipline: { name: "Hacked" } }

    assert @member.reload.kept?
    assert @discipline.reload.kept?
    assert_equal "Yoga", @discipline.name
  end

  test "unauthenticated requests go to login" do
    [ root_path, members_path, kiosk_root_path, reports_path ].each do |path|
      get path
      assert_redirected_to new_session_path
    end
  end

  test "member views hide archive for staff" do
    sign_in_as(@staff)

    get member_path(@member)
    assert_select "a", text: /Archivia Socio/, count: 0

    get members_path
    assert_select "a[href='#{edit_member_path(@member)}']"
  end

  test "member views show archive for admin" do
    sign_in_as(@admin)

    get member_path(@member)
    assert_select "a", text: /Archivia Socio/
  end

  test "subscription undo button follows the undo windows" do
    grant_membership_to(@member)
    current = sell!(member: @member, product: @product, user: @staff).subscription
    undo = "a[data-turbo-method=delete][href='#{subscription_path(current)}']"

    sign_in_as(users(:staff_two))
    get member_subscriptions_path(@member)
    assert_select undo, count: 0

    sign_in_as(@staff)
    get member_subscriptions_path(@member)
    assert_select undo

    travel Sale::STAFF_REVERSAL_WINDOW + 1.minute
    sign_in_as(@staff)
    get member_subscriptions_path(@member)
    assert_select undo, count: 0

    sign_in_as(@admin)
    get member_subscriptions_path(@member)
    assert_select undo
  end

  test "malformed params return bad request" do
    sign_in_as(@admin)
    post disciplines_path, params: { discipline: "x" }
    assert_response :bad_request
  end
end
