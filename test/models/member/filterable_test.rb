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

  test "without active membership is the complement" do
    assert_includes Member.without_active_membership, @bob
    assert_not_includes Member.without_active_membership, @alice
  end

  test "without any membership finds never-subscribed members" do
    assert_includes Member.without_any_membership, @bob
    assert_not_includes Member.without_any_membership, @alice
  end

  test "medical certificate scopes" do
    assert_includes Member.with_valid_med_cert, @alice
    assert_includes Member.with_expired_med_cert, @bob
    assert_includes Member.without_med_cert, members(:deleted)
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
