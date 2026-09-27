require "test_helper"

class Member::FilterableTest < ActiveSupport::TestCase
  setup do
    @alice = members(:alice)   # certificato valido
    @bob   = members(:bob)     # certificato scaduto
    grant_membership_to(@alice)
  end

  test "active membership finds members with a current associative subscription" do
    assert_includes Member.with_active_membership, @alice
    assert_not_includes Member.with_active_membership, @bob
  end

  test "active membership ignores course subscriptions" do
    Subscription.insert_all!([ { member_id: @bob.id, product_id: products(:yoga_monthly).id, start_date: Date.current,
                                 end_date: Date.current + 10, agreed_price_cents: 0, created_at: Time.current, updated_at: Time.current } ])
    assert_not_includes Member.with_active_membership, @bob
  end

  test "active membership ignores discarded subscriptions" do
    @alice.subscriptions.each(&:discard!)
    assert_not_includes Member.with_active_membership, @alice.reload
  end

  test "expired membership means a past membership and none valid today" do
    old = Subscription.create!(member: @bob, product: products(:annual_membership),
                               start_date: Date.current - 400, end_date: Date.current - 40)

    assert_includes Member.with_expired_membership, @bob
    assert_not_includes Member.with_expired_membership, @alice
    assert_not_includes Member.without_any_membership, @bob

    old.discard!
    assert_not_includes Member.with_expired_membership, @bob
  end

  test "a member who never had a membership is not expired" do
    assert_includes Member.without_any_membership, @bob
    assert_not_includes Member.with_expired_membership, @bob
    assert_not_includes Member.without_any_membership, @alice
  end

  test "courses and discarded memberships do not make a member tesserato" do
    Subscription.create!(member: @bob, product: products(:yoga_monthly), start_date: Date.current - 5, end_date: Date.current + 5)
    Subscription.create!(member: @bob, product: products(:annual_membership),
                         start_date: Date.current - 100, end_date: Date.current + 100).discard!

    assert_includes Member.without_any_membership, @bob
    assert_not_includes Member.with_active_membership, @bob
    assert_not_includes Member.with_expired_membership, @bob
  end

  test "active, expired and never are a partition of the members" do
    Subscription.create!(member: members(:deleted), product: products(:annual_membership),
                         start_date: Date.current - 400, end_date: Date.current - 40)
    groups = [ Member.with_active_membership, Member.with_expired_membership, Member.without_any_membership ].map { it.ids.sort }

    assert_equal Member.ids.sort, groups.flatten.sort
    assert_equal groups.flatten.size, groups.flatten.uniq.size
  end

  test "apply_filters maps the three membership states" do
    Subscription.create!(member: @bob, product: products(:annual_membership), start_date: Date.current - 400, end_date: Date.current - 40)

    assert_equal [ @alice ], Member.apply_filters(membership_status: "active").to_a
    assert_equal [ @bob ], Member.apply_filters(membership_status: "expired").to_a
    assert_not_includes Member.apply_filters(membership_status: "missing"), @bob
  end

  test "medical certificate scopes" do
    assert_includes Member.with_valid_med_cert, @alice
    assert_includes Member.with_expired_med_cert, @bob
    assert_includes Member.without_med_cert, members(:deleted)
  end

  test "enrolled_in finds members with a subscription of the discipline touching the period" do
    course = link!(products(:yoga_monthly), disciplines(:yoga))
    month = Date.new(2026, 10, 1).all_month
    Subscription.create!(member: @alice, product: course, start_date: Date.new(2026, 9, 1), end_date: Date.new(2026, 10, 1))
    Subscription.create!(member: @bob, product: course, start_date: Date.new(2026, 11, 1), end_date: Date.new(2026, 11, 30))

    assert_equal [ @alice ], Member.enrolled_in(disciplines(:yoga), during: month).to_a, "vale anche un solo giorno in comune"
    assert_equal [ @bob ], Member.enrolled_in(disciplines(:yoga), during: Date.new(2026, 11, 30)..Date.new(2026, 12, 31)).to_a
  end

  test "enrolled_in ignores other disciplines, memberships and discarded subscriptions" do
    link!(products(:yoga_monthly), disciplines(:yoga))
    pesi = link!(Product.create!(name: "Pesi Mensile", price_cents: 1000, duration_days: 30), disciplines(:sala_pesi))
    Subscription.create!(member: @bob, product: pesi, start_date: Date.current, end_date: Date.current + 10)
    Subscription.create!(member: @bob, product: products(:yoga_monthly), start_date: Date.current, end_date: Date.current + 10).discard!

    assert_empty Member.enrolled_in(disciplines(:yoga), during: Date.current.all_month)
    assert_equal [ @bob ], Member.enrolled_in(disciplines(:sala_pesi), during: Date.current.all_month).to_a
  end

  test "enrolled_in narrows to one product and lists a member once" do
    course = link!(products(:yoga_monthly), disciplines(:yoga))
    private_lessons = link!(Product.create!(name: "Yoga Privato", price_cents: 1000, duration_days: 30), disciplines(:yoga))
    Subscription.create!(member: @alice, product: course, start_date: Date.current.beginning_of_month, end_date: Date.current.end_of_month)
    Subscription.create!(member: @alice, product: private_lessons, start_date: Date.current.beginning_of_month, end_date: Date.current.end_of_month)
    Subscription.create!(member: @bob, product: private_lessons, start_date: Date.current.beginning_of_month, end_date: Date.current.end_of_month)

    month = Date.current.all_month
    assert_equal [ @alice ], Member.enrolled_in(disciplines(:yoga), during: month).where(id: @alice).to_a
    assert_equal [ @alice ], Member.enrolled_in(disciplines(:yoga), during: month, product_id: course.id).to_a
    assert_equal 2, Member.enrolled_in(disciplines(:yoga), during: month, product_id: private_lessons.id).count
  end

  test "enrollments_in picks the discipline subscriptions of the period, in order" do
    course = link!(products(:yoga_monthly), disciplines(:yoga))
    october  = Subscription.create!(member: @bob, product: course, start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 31))
    september = Subscription.create!(member: @bob, product: course, start_date: Date.new(2026, 9, 1), end_date: Date.new(2026, 9, 30))
    Subscription.create!(member: @bob, product: course, start_date: Date.new(2026, 12, 1), end_date: Date.new(2026, 12, 31))

    member = Member.preload(subscriptions: { product: :disciplines }).find(@bob.id)
    assert_equal [ september, october ], member.enrollments_in(disciplines(:yoga), during: Date.new(2026, 9, 15)..Date.new(2026, 10, 15))
    assert_empty member.enrollments_in(disciplines(:sala_pesi), during: Date.new(2026, 9, 1)..Date.new(2026, 12, 31))
  end

  test "without recent checkin hides members checked in within the kiosk cooldown" do
    AccessLog.create!(member: @alice, discipline: disciplines(:open_day), checkin_by_user: users(:staff))

    assert_not_includes Member.without_recent_checkin_for(disciplines(:open_day)), @alice
    assert_includes Member.without_recent_checkin_for(disciplines(:yoga)), @alice

    travel AccessLog::KIOSK_COOLDOWN + 1.minute
    assert_includes Member.without_recent_checkin_for(disciplines(:open_day)), @alice
  end

  test "sorted_by orders by name" do
    assert_equal [ @bob, @alice ], Member.kept.sorted_by("name_desc").to_a.last(2).reverse.reverse.select { [ @alice, @bob ].include?(it) }
    assert_equal @alice, Member.kept.sorted_by("name_asc").first
  end

  test "apply_filters excludes discarded members" do
    assert_not_includes Member.apply_filters({}), members(:deleted)
  end

  test "apply_filters combines membership and medical filters" do
    result = Member.apply_filters(membership_status: "active", med_cert: "valid")
    assert_equal [ @alice ], result.to_a

    assert_empty Member.apply_filters(membership_status: "active", med_cert: "expired")
  end

  test "apply_filters searches by name with full text" do
    assert_equal [ @alice ], Member.apply_filters(query: "alic").to_a
  end

  test "apply_filters ignores unknown filter values" do
    assert_equal Member.kept.count, Member.apply_filters(membership_status: "bogus", med_cert: "bogus").count
  end
end
