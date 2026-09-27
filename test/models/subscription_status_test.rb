require "test_helper"

class SubscriptionStatusTest < ActiveSupport::TestCase
  setup do
    @member = members(:alice)
    grant_membership_to(@member)
    @quota = products(:annual_membership)
  end

  def status_for(start_date:, end_date:, paid: true)
    sub = Subscription.create!(member: @member, product: products(:yoga_monthly), start_date:, end_date:,
                               agreed_price_cents: 1000)
    Sale.create!(member: @member, product: sub.product, user: users(:staff), sold_on: Date.current, amount_cents: 1000, subscription: sub) if paid
    sub.reload.status
  end

  test "active" do
    s = status_for(start_date: Date.current - 1, end_date: Date.current + 20)
    assert_equal [ :active, "Attivo" ], [ s.key, s.label ]
  end

  test "the period ignores payments" do
    s = status_for(start_date: Date.current - 1, end_date: Date.current + 20, paid: false)
    assert_equal [ :active, "Attivo" ], [ s.key, s.label ]
  end

  test "unpaid while running is due" do
    s = status_for(start_date: Date.current - 1, end_date: Date.current + 20, paid: false)
    assert_equal [ :due, "Da saldare" ], [ s.payment_key, s.payment_label ]
  end

  test "unpaid and expired is expired with an overdue debt, not due forever" do
    s = status_for(start_date: Date.current - 40, end_date: Date.current - 1, paid: false)
    assert_equal :expired, s.key
    assert_equal [ :overdue, "Insoluto" ], [ s.payment_key, s.payment_label ]
  end

  test "unpaid future subscription is due" do
    assert_equal :due, status_for(start_date: Date.current + 3, end_date: Date.current + 30, paid: false).payment_key
  end

  test "paid is paid in every period" do
    assert_equal :paid, status_for(start_date: Date.current - 40, end_date: Date.current - 1).payment_key
    assert_equal :paid, status_for(start_date: Date.current, end_date: Date.current + 20).payment_key
  end

  test "expired by date" do
    assert_equal :expired, status_for(start_date: Date.current - 40, end_date: Date.current - 1).key
  end


  test "future" do
    s = status_for(start_date: Date.current + 3, end_date: Date.current + 30)
    assert_equal :future, s.key
  end

  test "expiring soon within 7 days" do
    s = status_for(start_date: Date.current - 20, end_date: Date.current + 7)
    assert_equal :expiring_soon, s.key
  end

  test "zero-priced subscription counts as paid" do
    sub = Subscription.create!(member: @member, product: products(:yoga_monthly), start_date: Date.current, end_date: Date.current + 20, agreed_price_cents: 0)
    assert sub.fully_paid?
    assert_equal 0, sub.amount_due
  end

  test "every key has an italian label" do
    %i[expired future expiring_soon active].each do |key|
      s = SubscriptionStatus.new(nil)
      s.define_singleton_method(:key) { key }
      assert s.label.present?, key
    end

    %i[paid due overdue].each do |key|
      s = SubscriptionStatus.new(nil)
      s.define_singleton_method(:payment_key) { key }
      assert s.payment_label.present?, key
    end
  end
end
