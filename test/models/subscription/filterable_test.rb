require "test_helper"

class Subscription::FilterableTest < ActiveSupport::TestCase
  setup do
    Subscription.delete_all
    @alice = members(:alice)
    @bob   = members(:bob)
    @yoga  = products(:yoga_monthly)
    @quota = products(:annual_membership)

    @active   = Subscription.create!(member: @alice, product: @quota, start_date: Date.current.beginning_of_month, end_date: Date.current.end_of_month)
    @expired  = Subscription.create!(member: @bob, product: @quota, start_date: 2.months.ago.to_date, end_date: 1.month.ago.to_date)
    @upcoming = Subscription.create!(member: @bob, product: @yoga, start_date: 1.month.from_now.to_date, end_date: 2.months.from_now.to_date)
  end

  test "by_state splits active, expired and upcoming" do
    assert_equal [ @active ], Subscription.by_state("active").to_a
    assert_equal [ @expired ], Subscription.by_state("expired").to_a
    assert_equal [ @upcoming ], Subscription.by_state("upcoming").to_a
    assert_equal 3, Subscription.by_state(nil).count
  end

  test "by_product filters and ignores blank" do
    assert_equal [ @upcoming ], Subscription.by_product(@yoga.id).to_a
    assert_equal 3, Subscription.by_product("").count
  end

  test "search_text goes through member full text search" do
    assert_equal [ @active ], Subscription.search_text("Alice").to_a
  end

  test "deduplicate_by_member keeps the latest per member" do
    assert_equal [ @active, @upcoming ].sort_by(&:id), Subscription.deduplicate_by_member.sort_by(&:id)
  end

  test "sorted_by expiring" do
    assert_equal @expired, Subscription.sorted_by("expiring_asc").first
    assert_equal @upcoming, Subscription.sorted_by("expiring_desc").first
  end

  test "active_at ignores discarded subscriptions" do
    assert Subscription.active_at(Date.current).exists?(@active.id)
    @active.discard!
    assert_not Subscription.active_at(Date.current).exists?(@active.id)
  end

  test "for_discipline uses product links" do
    link!(@yoga, disciplines(:yoga))
    assert_equal [ @upcoming ], Subscription.for_discipline(disciplines(:yoga)).to_a
  end

  test "apply_filters by med cert and membership" do
    assert_equal [ @upcoming ], Subscription.apply_filters(med_cert: "expired").to_a
    assert_equal [ @active ], Subscription.apply_filters(membership_status: "active").to_a
  end
end
