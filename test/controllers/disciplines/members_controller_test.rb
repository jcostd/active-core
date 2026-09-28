require "test_helper"

class Disciplines::MembersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @yoga = disciplines(:yoga)
    @course = link!(products(:yoga_monthly), @yoga)
    @alice = members(:alice)
    grant_membership_to(@alice)
    sign_in_as(users(:staff))
  end

  def row(member) = "##{ActionView::RecordIdentifier.dom_id(member)}"
  def this_month = Date.current.strftime("%Y-%m")
  def last_month = Date.current.prev_month

  def enrolled(member, period = Date.current.all_month)
    grant_membership_to(member)
    Subscription.create!(member:, product: @course, start_date: period.first, end_date: period.last)
    member
  end

  test "lists the members enrolled this month, once each, with their subscriptions" do
    this_month = sell!(member: @alice, product: @course).subscription
    extra = link!(Product.create!(name: "Yoga Privato", price_cents: 1000, duration_days: 30), @yoga)
    Subscription.create!(member: @alice, product: extra, start_date: Date.current.beginning_of_month, end_date: Date.current.end_of_month)

    get discipline_members_path(@yoga)
    assert_response :success
    assert_select row(@alice), count: 1
    assert_select "#{row(@alice)} .badge", text: /#{this_month.product.name}/
    assert_select "#{row(@alice)} .badge", text: /Yoga Privato/
    assert_select "h2", text: /Iscritti di #{I18n.l(Date.current, format: "%B %Y")}/
  end

  test "shows who the instructor has seen this month" do
    sell!(member: @alice, product: @course)
    bob = enrolled(members(:bob))
    Attendance.create!(member: @alice, discipline: @yoga, marked_by: users(:kiosk))
    Attendance.create!(member: bob, discipline: disciplines(:sala_pesi), marked_by: users(:kiosk))

    get discipline_members_path(@yoga)
    assert_select "#{row(@alice)} .badge[title='Segnato da Kiosk Accessi']", text: /Visto/
    assert_select "#{row(bob)} .badge", text: /Visto/, count: 0
    assert_select "#{row(bob)} form[action='#{discipline_attendances_path(@yoga)}'] button", text: "Segna visto"
  end

  test "the desk marks a member seen in the current month" do
    bob = enrolled(members(:bob))

    assert_difference -> { Attendance.count } do
      post discipline_attendances_path(@yoga), params: { member_id: bob.id, month: this_month }
    end
    assert_redirected_to discipline_members_path(@yoga, month: this_month)
    assert_equal "Bob Bianchi è nel registro di #{I18n.l(Date.current, format: "%B %Y")}.", flash[:notice]
    assert_equal users(:staff), Attendance.last.marked_by
  end

  test "the desk refuses a second mark with a message" do
    Attendance.create!(member: @alice, discipline: @yoga, marked_by: users(:kiosk))

    assert_no_difference -> { Attendance.count } do
      post discipline_attendances_path(@yoga), params: { member_id: @alice.id, month: this_month }
    end
    assert_equal "Socio è già nel registro di questo mese", flash[:alert]
  end

  test "the desk removes a mark of the current month, after a confirmation" do
    sell!(member: @alice, product: @course)
    attendance = Attendance.create!(member: @alice, discipline: @yoga, marked_by: users(:kiosk))

    get discipline_members_path(@yoga)
    assert_select "#{row(@alice)} form[data-turbo-confirm='Togliere Alice Allevi dal registro di #{I18n.l(Date.current, format: "%B %Y")}?']"

    delete discipline_attendance_path(@yoga, attendance)
    assert_redirected_to discipline_members_path(@yoga, month: this_month)
    assert_not Attendance.exists?(attendance.id)
    assert_equal "Alice Allevi non è più nel registro di #{I18n.l(Date.current, format: "%B %Y")}.", flash[:notice]
  end

  test "staff cannot correct a closed month, neither from the page nor by request" do
    closed = Attendance.create!(member: @alice, discipline: @yoga, month: last_month, marked_by: users(:admin))
    bob = enrolled(members(:bob), last_month.all_month)
    enrolled(@alice, last_month.all_month)

    get discipline_members_path(@yoga, month: last_month.strftime("%Y-%m"))
    assert_select "#discipline_members form", count: 0
    assert_select "#{row(bob)} .badge", text: "Non visto"

    assert_no_difference -> { Attendance.count } do
      post discipline_attendances_path(@yoga), params: { member_id: bob.id, month: last_month.strftime("%Y-%m") }
    end
    assert_equal "Mese è chiuso: solo un amministratore può correggerlo", flash[:alert]

    delete discipline_attendance_path(@yoga, closed)
    assert Attendance.exists?(closed.id)
    assert_equal "Il registro di #{I18n.l(last_month, format: "%B %Y")} è chiuso: può correggerlo solo un amministratore.", flash[:alert]
  end

  test "the admin corrects a closed month" do
    sign_in_as(users(:admin))
    bob = enrolled(members(:bob), last_month.all_month)

    get discipline_members_path(@yoga, month: last_month.strftime("%Y-%m"))
    assert_select "#{row(bob)} button", text: "Segna visto"

    post discipline_attendances_path(@yoga), params: { member_id: bob.id, month: last_month.strftime("%Y-%m") }
    attendance = Attendance.last
    assert_equal [ bob, last_month.beginning_of_month ], [ attendance.member, attendance.month ]

    delete discipline_attendance_path(@yoga, attendance)
    assert_not Attendance.exists?(attendance.id)
  end

  test "nobody marks a month that has not started" do
    sign_in_as(users(:admin))
    next_month = Date.current.next_month
    bob = enrolled(members(:bob), next_month.all_month)

    get discipline_members_path(@yoga, month: next_month.strftime("%Y-%m"))
    assert_select "#{row(bob)} form", count: 0

    assert_no_difference -> { Attendance.count } do
      post discipline_attendances_path(@yoga), params: { member_id: bob.id, month: next_month.strftime("%Y-%m") }
    end
    assert_equal "Mese non è ancora iniziato", flash[:alert]
  end

  test "a malformed month marks the current one" do
    post discipline_attendances_path(@yoga), params: { member_id: @alice.id, month: "2026-13" }
    assert_equal Date.current.beginning_of_month, Attendance.last.month
  end

  test "a mark is removed only through its own discipline" do
    attendance = Attendance.create!(member: @alice, discipline: disciplines(:sala_pesi), marked_by: users(:kiosk))

    delete discipline_attendance_path(@yoga, attendance)
    assert_response :not_found
    assert Attendance.exists?(attendance.id)
  end

  test "filters the enrolled seen or not seen by the instructor" do
    sell!(member: @alice, product: @course)
    bob = enrolled(members(:bob))
    Attendance.create!(member: @alice, discipline: @yoga, marked_by: users(:kiosk))

    get discipline_members_path(@yoga, seen: "yes")
    assert_select row(@alice)
    assert_select row(bob), count: 0

    get discipline_members_path(@yoga, seen: "no")
    assert_select row(@alice), count: 0
    assert_select row(bob)
  end

  test "who attends without a subscription is listed apart, ready to be sold one" do
    sell!(member: @alice, product: @course)
    hugo = Member.create!(first_name: "Hugo", last_name: "Nuovo", birth_date: 20.years.ago, fiscal_code_pending: true)
    Attendance.create!(member: @alice, discipline: @yoga, marked_by: users(:kiosk))
    attendance = Attendance.create!(member: hugo, discipline: @yoga, marked_by: users(:kiosk))

    get discipline_members_path(@yoga)
    assert_select "#unenrolled_attendances h3", text: /Frequentano senza abbonamento \(1\)/
    assert_select "#unenrolled_attendances li", count: 1
    assert_select "##{ActionView::RecordIdentifier.dom_id(attendance, :unenrolled)}", text: /Hugo Nuovo\s*Segnato da Kiosk Accessi/
    assert_select "#unenrolled_attendances a[href='#{new_sale_path(member_id: hugo.id)}'][data-turbo-frame=modal]", text: /Vendi/
    assert_select "#unenrolled_attendances form[action='#{discipline_attendance_path(@yoga, attendance)}']"
    assert_select row(hugo), { count: 0 }, "non è tra gli iscritti"
  end

  test "the unenrolled section follows the chosen month" do
    Attendance.create!(member: members(:bob), discipline: @yoga, month: last_month, marked_by: users(:admin))

    get discipline_members_path(@yoga)
    assert_select "#unenrolled_attendances", count: 0

    get discipline_members_path(@yoga, month: last_month.strftime("%Y-%m"))
    assert_select "#unenrolled_attendances", text: /Bob Bianchi/
    assert_select "#unenrolled_attendances form", { count: 0 }, "mese chiuso: lo staff non corregge"
  end

  test "the page refreshes when the register changes" do
    get discipline_members_path(@yoga)
    assert_select "turbo-cable-stream-source"
  end

  test "another month shows who was enrolled then" do
    last_month = Date.current.prev_month
    bob = members(:bob)
    grant_membership_to(bob)
    Subscription.create!(member: bob, product: @course, start_date: last_month.beginning_of_month, end_date: last_month.end_of_month)

    get discipline_members_path(@yoga)
    assert_select row(bob), count: 0

    get discipline_members_path(@yoga, month: last_month.strftime("%Y-%m"))
    assert_select row(bob)
    assert_select "a[href*='month=#{last_month.prev_month.strftime("%Y-%m")}']"
  end

  test "filters by product, keeping the month" do
    sell!(member: @alice, product: @course)
    other = link!(Product.create!(name: "Yoga Privato", price_cents: 1000, duration_days: 30), @yoga)

    get discipline_members_path(@yoga, product_id: other.id)
    assert_select row(@alice), count: 0

    get discipline_members_path(@yoga, product_id: @course.id, month: Date.current.strftime("%Y-%m"))
    assert_select row(@alice)
    assert_select "#filter-form input[type=hidden][name=month][value='#{Date.current.strftime("%Y-%m")}']"
  end

  test "archived members and other disciplines are left out" do
    sell!(member: @alice, product: @course)
    @alice.discard!

    get discipline_members_path(@yoga)
    assert_select row(@alice), count: 0
    assert_match "Nessun iscritto", response.body
  end

  test "invalid month falls back to this month" do
    sell!(member: @alice, product: @course)

    get discipline_members_path(@yoga, month: "2026-13")
    assert_response :success
    assert_select row(@alice)
  end

  test "sorted by name by default" do
    sell!(member: @alice, product: @course)
    bob = members(:bob)
    grant_membership_to(bob)
    sell!(member: bob, product: @course)

    get discipline_members_path(@yoga)
    ids = css_select("#discipline_members > li").map { it["id"] }
    assert_equal [ row(@alice), row(bob) ].map { it.delete("#") }, ids
  end

  test "the page lists the same members the kiosk proposes" do
    sell!(member: @alice, product: @course)

    get discipline_members_path(@yoga)
    listed = css_select("#discipline_members > li").map { it["id"] }

    get kiosk_discipline_path(@yoga)
    proposed = css_select("[id^='pending_member_']").map { it["id"].delete_prefix("pending_") }

    assert_equal listed.sort, proposed.sort
  end
end
