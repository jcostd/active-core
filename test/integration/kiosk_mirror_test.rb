require "test_helper"

# il kiosk è lo specchio della segreteria: chi è iscritto questo mese l'istruttore lo trova
# da smarcare o già nel registro, e chi frequenta senza essere iscritto lo vede la segreteria
class KioskMirrorTest < ActionDispatch::IntegrationTest
  setup do
    @yoga = disciplines(:yoga)
    @course = link!(products(:yoga_monthly), @yoga)
    month = Date.current.all_month

    @alice = enroll(members(:alice), month)
    @bob   = enroll(members(:bob), Date.current.prev_month.all_month)
    @carla = enroll(person("Carla"), month)
    @elena = enroll(person("Elena"), Date.current.next_month.all_month)
    @dario = enroll(person("Dario"), month).tap { it.subscriptions.last.discard! }
    @franco = enroll(person("Franco"), month).tap(&:discard!)
    enroll(person("Gino"), month, product: products(:annual_membership))
    @hugo = person("Hugo")

    mark(@bob, Date.current.prev_month)
    mark(@carla)
    mark(@hugo)
    sign_in_as(users(:staff))
  end

  test "whoever is enrolled this month is to be marked or already in the register" do
    enrolled, pending, register = iscritti, kiosk_pending, kiosk_register

    assert_equal ids_of(@alice, @carla), enrolled
    assert_equal ids_of(@alice, @bob), pending, "iscritti del mese e presenti il mese scorso"
    assert_equal ids_of(@carla, @hugo), register
    assert_empty enrolled - pending - register
    assert_empty pending & register, "nessuno in due liste"
  end

  test "who is in the register but not enrolled is what the desk must regularize" do
    to_regularize = kiosk_register - iscritti

    assert_equal ids_of(@hugo), to_regularize
    get discipline_members_path(@yoga)
    assert_equal to_regularize, css_select("#unenrolled_attendances li a[href^='/members/']").map { it["href"].delete_prefix("/members/").to_i }.uniq.sort

    get root_path
    assert_equal to_regularize, css_select("#unenrolled_attendances li a[href^='/members/']").map { it["href"].delete_prefix("/members/").to_i }.uniq.sort
  end

  test "once sold a subscription, a walk-in leaves the list to regularize and joins the enrolled" do
    grant_membership_to(@hugo)
    sell!(member: @hugo, product: @course, start_date: Date.current.beginning_of_month)

    assert_includes iscritti, @hugo.id
    assert_includes kiosk_register, @hugo.id
    get discipline_members_path(@yoga)
    assert_select "#unenrolled_attendances", count: 0
  end

  test "next month's enrolled are proposed when their month starts" do
    assert_not_includes kiosk_pending, @elena.id

    travel_to Date.current.next_month.beginning_of_month.in_time_zone.change(hour: 18)
    sign_in_as(users(:staff))
    assert_includes kiosk_pending, @elena.id
    assert_includes iscritti, @elena.id
    assert_empty kiosk_register, "ogni mese riparte da un registro vuoto"
    assert_includes kiosk_pending, @carla.id, "chi c'era il mese scorso viene riproposto"
  end

  private
    def iscritti
      get discipline_members_path(@yoga)
      css_select("#discipline_members li[id^='member_']").map { it["id"].delete_prefix("member_").to_i }.sort
    end

    def kiosk_pending
      get kiosk_discipline_path(@yoga)
      css_select("[id^='pending_member_']").map { it["id"].delete_prefix("pending_member_").to_i }.sort
    end

    def kiosk_register
      get kiosk_discipline_path(@yoga)
      Attendance.where(id: css_select("#attendances [id^='attendance_']").map { it["id"].delete_prefix("attendance_") }).pluck(:member_id).sort
    end

    def person(name) = Member.create!(first_name: name, last_name: "Prova", birth_date: 30.years.ago, fiscal_code_pending: true)

    def enroll(member, period, product: @course)
      Subscription.create!(member:, product:, start_date: period.first, end_date: period.last)
      member
    end

    def mark(member, month = Date.current) = Attendance.create!(member:, discipline: @yoga, month:, marked_by: users(:admin))

    def ids_of(*members) = members.map(&:id).sort
end
