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

  test "pending payment wins over everything" do
    s = status_for(start_date: Date.current - 1, end_date: Date.current + 20, paid: false)
    assert_equal :pending_payment, s.key
    assert_equal "Da Saldare", s.label
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
    %i[pending_payment expired future expiring_soon active].each do |key|
      s = SubscriptionStatus.new(nil)
      s.define_singleton_method(:key) { key }
      assert s.label.present?, key
    end
  end
end
