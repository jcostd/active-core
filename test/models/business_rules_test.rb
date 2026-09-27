require "test_helper"

# regole di business con valori assoluti: se qualcuno cambia una costante il test lo segnala
class BusinessRulesTest < ActiveSupport::TestCase
  setup do
    @member = members(:alice)
    grant_membership_to(@member)
    @sale = sell!(member: @member, product: products(:yoga_monthly), amount: 10)
  end

  test "staff undoes own payment for 15 minutes" do
    travel 14.minutes + 59.seconds
    assert @sale.reversible_by?(users(:staff))

    travel 2.seconds
    assert_not @sale.reversible_by?(users(:staff))
  end

  test "admin undoes any payment for 24 hours" do
    travel 23.hours + 59.minutes
    assert @sale.reversible_by?(users(:admin))

    travel 2.minutes
    assert_not @sale.reversible_by?(users(:admin))
  end

  test "sessions expire after one hour of inactivity" do
    session = users(:staff).sessions.create!
    travel 59.minutes
    assert_not session.expired?

    travel 2.minutes
    assert session.expired?
  end

  test "kiosk sessions last 30 days" do
    session = users(:kiosk).sessions.create!
    travel 29.days
    assert_not session.expired?

    travel 2.days
    assert session.expired?
  end

  test "double check-in is blocked for 10 minutes" do
    attrs = { member: @member, discipline: disciplines(:yoga), checkin_by_user: users(:staff) }
    AccessLog.create!(attrs)

    travel 9.minutes + 59.seconds
    assert_not AccessLog.new(attrs).valid?

    travel 2.seconds
    assert AccessLog.new(attrs).valid?
  end

  test "kiosk hides members checked in within the last hour" do
    AccessLog.create!(member: @member, discipline: disciplines(:yoga), checkin_by_user: users(:staff))

    travel 59.minutes
    assert_not_includes Member.without_recent_checkin_for(disciplines(:yoga)), @member

    travel 2.minutes
    assert_includes Member.without_recent_checkin_for(disciplines(:yoga)), @member
  end

  test "renewal grace period is 30 days" do
    quota = products(:annual_membership)
    bob = members(:bob)
    Subscription.create!(member: bob, product: quota, start_date: Date.new(2024, 9, 1), end_date: Date.new(2025, 8, 31))

    assert_equal Date.new(2025, 9, 1), bob.suggested_start_date_for(quota, Date.new(2025, 10, 1)), "30 giorni: continuità"
    assert_equal Date.new(2025, 10, 2), bob.suggested_start_date_for(quota, Date.new(2025, 10, 2)), "31 giorni: si riparte"
  end

  test "cash is split at 14:00" do
    Sale.delete_all
    travel_to Date.current.in_time_zone.change(hour: 13, min: 59) do
      sell!(member: @member, product: products(:yoga_monthly), amount: 1, agreed_price: 100, start_date: Date.current + 40)
    end
    travel_to Date.current.in_time_zone.change(hour: 14) do
      sell!(member: @member, product: products(:yoga_monthly), amount: 2, agreed_price: 100, start_date: Date.current + 80)
    end

    report = DailyCash.for(Date.current)
    assert_equal [ 100, 200 ], [ report.morning_cents, report.afternoon_cents ]
  end

  test "expiring means within 7 days" do
    bob = members(:bob)
    seven = Subscription.create!(member: bob, product: products(:yoga_monthly), start_date: Date.current - 20, end_date: Date.current + 7)
    other = Product.create!(name: "Nuoto Mensile", price_cents: 3000, duration_days: 30)
    eight = Subscription.create!(member: bob, product: other, start_date: Date.current - 20, end_date: Date.current + 8)

    assert_includes Subscription.expiring, seven
    assert_not_includes Subscription.expiring, eight
  end

  test "kiosk warns about expiry 7 days ahead, not 8" do
    course = link!(products(:yoga_monthly), disciplines(:yoga))
    @sale.subscription.discard!
    sub = Subscription.create!(member: @member, product: course, start_date: Date.current - 20, end_date: Date.current + 8)
    policy = -> { AccessPolicy.new(member: @member.reload, discipline: disciplines(:yoga)).evaluate!.warnings }

    assert_empty policy.call
    sub.update_columns(end_date: Date.current + 7)
    assert_includes policy.call, "Abbonamento in scadenza tra 7 giorni."
  end

  test "staff may start exactly on the proposed date, not a day earlier" do
    course = Product.create!(name: "Corso 45 giorni", price_cents: 1000, duration_days: 45)
    proposed = Subscription.proposed_start_date(@member, course)
    build = ->(start) {
      Sale.new(member: @member, product: course, user: users(:staff), sold_on: Date.current,
               subscription_attributes: { member: @member, product: course, start_date: start, end_date: start + 44 })
    }

    assert build.(proposed).valid?
    assert_not build.(proposed - 1).valid?
  end

  test "overpaid subscriptions owe nothing, never a negative amount" do
    sub = @sale.subscription
    sub.update_columns(agreed_price_cents: 500)
    assert_equal 0, sub.amount_due
    assert sub.fully_paid?
  end

  test "semester course is capped at the end of the sport year" do
    semester = Product.new(duration_days: 180, accounting_category: :institutional)
    assert_equal Date.new(2026, 8, 31), Duration.for(semester, Date.new(2026, 4, 10)).end_date
    assert_equal Date.new(2027, 2, 28), Duration.for(semester, Date.new(2026, 9, 10)).end_date
  end

  test "quarterly course is not capped" do
    quarterly = Product.new(duration_days: 90, accounting_category: :institutional)
    assert_equal Date.new(2026, 9, 30), Duration.for(quarterly, Date.new(2026, 7, 5)).end_date
  end
end
