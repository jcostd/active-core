require "test_helper"

# registro presenze del mese: l'istruttore smarca chi vede, una volta al mese, qualunque sia lo stato
class KioskFlowTest < ActionDispatch::IntegrationTest
  setup do
    @alice, @bob = members(:alice), members(:bob)
    @yoga = disciplines(:yoga)
    grant_membership_to(@alice)
    @course = link!(products(:yoga_monthly), @yoga)
    @month = Date.current.all_month
    sign_in_as(users(:kiosk))
  end

  test "home lists kept disciplines" do
    get kiosk_root_path
    assert_response :success
    assert_match "Yoga", response.body
    assert_no_match ">Pilates<", response.body
    assert_match "registro del mese", response.body
  end

  test "page names the register of the current month" do
    get kiosk_discipline_path(@yoga)
    assert_select "h2", text: "Yoga"
    assert_select "p", text: "Registro di #{I18n.l(Date.current, format: "%B %Y")}"
  end

  test "an empty month proposes the enrolled members" do
    sell!(member: @alice, product: @course)

    get kiosk_discipline_path(@yoga)
    assert_select "#pending_members #{pending(@alice)}"
    assert_select "#attendances .card", count: 0
    assert_select "#attendances", text: /Registro vuoto/
  end

  test "marking moves the member into the register" do
    sell!(member: @alice, product: @course)

    assert_difference -> { Attendance.count } do
      post kiosk_discipline_attendances_path(@yoga, member_id: @alice.id)
    end
    assert_redirected_to kiosk_discipline_path(@yoga)
    assert_equal "Alice è nel registro di #{I18n.l(Date.current, format: "%B")}", flash[:success]

    attendance = Attendance.last
    assert_equal [ @alice, @yoga, @month.first, users(:kiosk) ], [ attendance.member, attendance.discipline, attendance.month, attendance.marked_by ]

    follow_redirect!
    assert_select "#attendances #{dom(attendance)}", text: /Alice Allevi/
    assert_select "#pending_members #{pending(@alice)}", count: 0
  end

  test "a member is marked once a month" do
    post kiosk_discipline_attendances_path(@yoga, member_id: @alice.id)

    assert_no_difference -> { Attendance.count } do
      post kiosk_discipline_attendances_path(@yoga, member_id: @alice.id)
    end
    assert_equal "Impossibile smarcare Alice: Socio è già nel registro di questo mese", flash[:error]
  end

  test "whoever the instructor sees is marked, whatever the subscription" do
    post kiosk_discipline_attendances_path(@yoga, member_id: @bob.id)

    assert Attendance.exists?(member: @bob, discipline: @yoga)
    assert_equal "Bob è nel registro di #{I18n.l(Date.current, format: "%B")}: Non iscritto, Certificato scaduto", flash[:error]
  end

  test "the flash tells what is still to pay" do
    Subscription.create!(member: @alice, product: @course, start_date: @month.first, end_date: @month.last)

    post kiosk_discipline_attendances_path(@yoga, member_id: @alice.id)
    assert_equal "Alice è nel registro di #{I18n.l(Date.current, format: "%B")}: Da saldare", flash[:info]
  end

  test "register cards show the standing of each member" do
    sell!(member: @alice, product: @course)
    Subscription.create!(member: @bob, product: @course, start_date: @month.first, end_date: @month.last)
    carla = person("Carla")
    [ @alice, @bob, carla ].each { mark(it) }

    get kiosk_discipline_path(@yoga)
    assert_select "#attendances .card", count: 3
    assert_select "#attendances .card", text: /Alice Allevi\s+Saldato/
    assert_select "#attendances .card", text: /Bob Bianchi\s+Quota mancante\s+Cert. scaduto/
    assert_select "#attendances .card", text: /Carla Prova\s+Non iscritto/
    assert_select "#attendances .card.bg-error\\/5", count: 2
  end

  test "a payment made at the desk shows up at the next refresh" do
    subscription = Subscription.create!(member: @alice, product: @course, start_date: @month.first, end_date: @month.last)
    mark(@alice)

    get kiosk_discipline_path(@yoga)
    assert_select "#attendances .card", text: /Da saldare/

    Sale.create!(member: @alice, product: @course, user: users(:staff), subscription:, payment_method: :cash)
    get kiosk_discipline_path(@yoga)
    assert_select "#attendances .card", text: /Saldato/
  end

  test "last month's attendees are proposed even if their subscription ended" do
    Subscription.create!(member: @bob, product: @course, start_date: @month.first.prev_month, end_date: @month.first.prev_month.end_of_month)
    mark(@bob, month: @month.first.prev_month)

    get kiosk_discipline_path(@yoga)
    assert_select "#pending_members #{pending(@bob)}", text: /Non iscritto/
  end

  test "who is neither enrolled this month nor came last month is not proposed" do
    carla, dario, elena = person("Carla"), person("Dario"), person("Elena")
    mark(carla, month: @month.first.months_ago(2))
    Subscription.create!(member: dario, product: @course, start_date: @month.first.next_month, end_date: @month.first.next_month.end_of_month)
    Subscription.create!(member: elena, product: @course, start_date: @month.first, end_date: @month.last).discard!
    mark(@alice, discipline: disciplines(:sala_pesi), month: @month.first.prev_month)

    get kiosk_discipline_path(@yoga)
    [ carla, dario, elena, @alice ].each { assert_select pending(it), count: 0 }
  end

  test "the register shows only the current month" do
    old = mark(@alice, month: @month.first.prev_month)

    get kiosk_discipline_path(@yoga)
    assert_select dom(old), count: 0
    assert_select "#pending_members #{pending(@alice)}"
  end

  test "a mistaken mark is removed and the member is proposed again" do
    sell!(member: @alice, product: @course)
    attendance = mark(@alice)

    get kiosk_discipline_path(@yoga)
    assert_select "#{dom(attendance)} form[data-turbo-confirm='Togliere Alice Allevi dal registro di #{I18n.l(Date.current, format: "%B")}?']"

    assert_difference -> { Attendance.count }, -1 do
      delete kiosk_discipline_attendance_path(@yoga, attendance)
    end
    assert_redirected_to kiosk_discipline_path(@yoga)
    assert_equal "Alice non è più nel registro di #{I18n.l(Date.current, format: "%B")}.", flash[:success]

    follow_redirect!
    assert_select "#pending_members #{pending(@alice)}"
  end

  test "a closed month cannot be corrected from the kiosk" do
    closed = mark(@alice, month: @month.first.prev_month)

    assert_no_difference -> { Attendance.count } do
      delete kiosk_discipline_attendance_path(@yoga, closed)
    end
    assert_equal "Il registro di #{I18n.l(@month.first.prev_month, format: "%B %Y")} è chiuso: può correggerlo solo un amministratore.", flash[:error]
  end

  test "an admin at the kiosk may correct a closed month" do
    closed = mark(@alice, month: @month.first.prev_month)
    sign_in_as(users(:admin))

    delete kiosk_discipline_attendance_path(@yoga, closed)
    assert_not Attendance.exists?(closed.id)
  end

  test "an attendance is removed only through its own discipline" do
    attendance = mark(@alice, discipline: disciplines(:sala_pesi))

    delete kiosk_discipline_attendance_path(@yoga, attendance)
    assert_response :not_found
    assert Attendance.exists?(attendance.id)
  end

  test "search offers to mark members not yet in the register" do
    mark(@alice)
    bianca = Member.create!(first_name: "Alina", last_name: "Bianca", birth_date: 20.years.ago, fiscal_code_pending: true)

    get kiosk_discipline_member_searches_path(@yoga, query: "Ali")
    assert_select "##{ActionView::RecordIdentifier.dom_id(@alice, :search_result)}", text: /Già nel registro/
    assert_select "##{ActionView::RecordIdentifier.dom_id(@alice, :search_result)} form", count: 0
    assert_select "form[action='#{kiosk_discipline_attendances_path(@yoga, member_id: bianca.id)}']"
  end

  test "search result marks the member" do
    post kiosk_discipline_attendances_path(@yoga, member_id: @bob.id)
    assert_redirected_to kiosk_discipline_path(@yoga)
    assert Attendance.exists?(member: @bob)
  end

  test "search hides fiscal code and full birth date" do
    get kiosk_discipline_member_searches_path(@yoga, query: "Ali")

    assert_no_match @alice.fiscal_code, response.body
    assert_no_match I18n.l(@alice.birth_date), response.body
    assert_match "Nato/a nel #{@alice.birth_date.year}", response.body
  end

  test "search finds members only by name" do
    get kiosk_discipline_member_searches_path(@yoga, query: "Allevi")
    assert_match @alice.full_name, response.body

    [ @alice.fiscal_code.first(6), "alice@example", "3331234567" ].each do |query|
      get kiosk_discipline_member_searches_path(@yoga, query:)
      assert_no_match @alice.full_name, response.body, "il kiosk non deve trovare soci per #{query}"
    end
  end

  test "search box asks for a name, not a fiscal code" do
    get kiosk_discipline_path(@yoga)
    assert_select "input[placeholder='Cerca nome o cognome di chi non è in lista...']"
  end

  test "register pages never show fiscal codes or birth dates" do
    sell!(member: @alice, product: @course)
    mark(@bob)

    get kiosk_discipline_path(@yoga)
    [ @alice, @bob ].each do |member|
      assert_no_match member.fiscal_code, response.body if member.fiscal_code
      assert_no_match I18n.l(member.birth_date), response.body
    end
  end

  test "the page listens for register and member changes" do
    get kiosk_discipline_path(@yoga)
    assert_select "turbo-cable-stream-source", count: 2
  end

  private
    def person(name) = Member.create!(first_name: name, last_name: "Prova", birth_date: 30.years.ago, fiscal_code_pending: true)

    def mark(member, discipline: @yoga, month: nil)
      Attendance.create!(member:, discipline:, month:, marked_by: users(:admin))
    end

    def pending(member) = "##{ActionView::RecordIdentifier.dom_id(member, :pending)}"
    def dom(record) = "##{ActionView::RecordIdentifier.dom_id(record)}"
end
