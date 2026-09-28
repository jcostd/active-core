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

  test "shows how many times each member came this month" do
    travel_to Time.current.beginning_of_month.change(hour: 12) # due ingressi a 20 minuti, nello stesso mese
    sign_in_as(users(:staff))
    sell!(member: @alice, product: @course)
    AccessLog.create!(member: @alice, discipline: @yoga, checkin_by_user: users(:staff), entered_at: 20.minutes.ago)
    AccessLog.create!(member: @alice, discipline: @yoga, checkin_by_user: users(:staff), entered_at: Time.current)
    AccessLog.create!(member: @alice, discipline: disciplines(:sala_pesi), checkin_by_user: users(:staff), entered_at: Time.current)

    get discipline_members_path(@yoga)
    assert_select "#{row(@alice)} span", text: "2"
    assert_select "#{row(@alice)} span", text: "presenze"
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
