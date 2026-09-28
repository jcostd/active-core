require "test_helper"

# il kiosk è lo specchio della segreteria: chi è iscritto questo mese lo trova l'istruttore all'appello
class KioskMirrorTest < ActionDispatch::IntegrationTest
  setup do
    @yoga = disciplines(:yoga)
    @course = link!(products(:yoga_monthly), @yoga)
    month = Date.current.all_month

    @alice  = enroll(members(:alice), month)
    @bob    = enroll(members(:bob), Date.current.prev_month.all_month)
    @carla  = enroll(person("Carla"), month)
    @elena  = enroll(person("Elena"), Date.current.next_month.all_month)
    @dario  = enroll(person("Dario"), month).tap { it.subscriptions.last.discard! }
    @franco = enroll(person("Franco"), month).tap(&:discard!)
    enroll(person("Gino"), month, product: products(:annual_membership))

    @carla_checkin = AccessLog.create!(member: @carla, discipline: @yoga, checkin_by_user: users(:kiosk), entered_at: 5.minutes.ago)
    sign_in_as(users(:staff))
  end

  test "whoever is enrolled this month is on the roll call or already in the room" do
    get discipline_members_path(@yoga)
    enrolled = ids("li[id^='member_']", "member_")

    get kiosk_discipline_path(@yoga)
    pending = ids("[id^='pending_member_']", "pending_member_")

    assert_equal ids_of(@alice, @carla), enrolled
    assert_equal ids_of(@alice, @bob, @elena), pending, "il kiosk guarda anche i mesi vicini"
    assert_select "##{dom_id(@carla_checkin)}"
    assert_empty enrolled - pending - [ @carla.id ]
  end

  test "next month's enrolled are already on this month's roll call" do
    get discipline_members_path(@yoga, month: Date.current.next_month.strftime("%Y-%m"))
    enrolled = ids("li[id^='member_']", "member_")

    get kiosk_discipline_path(@yoga)
    assert_includes enrolled, @elena.id
    assert_includes ids("[id^='pending_member_']", "pending_member_"), @elena.id
  end

  private
    def person(name) = Member.create!(first_name: name, last_name: "Prova", birth_date: 30.years.ago, fiscal_code_pending: true)

    def enroll(member, period, product: @course)
      Subscription.create!(member:, product:, start_date: period.first, end_date: period.last)
      member
    end

    def ids(selector, prefix) = css_select(selector).map { it["id"].delete_prefix(prefix).to_i }.sort

    def ids_of(*members) = members.map(&:id).sort
end
