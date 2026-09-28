require "test_helper"

class SubscriptionRenewalTest < ActiveSupport::TestCase
  setup do
    @alice = members(:alice)
    @yoga_discipline = disciplines(:yoga)
    @monthly = link!(products(:yoga_monthly), @yoga_discipline)
    @quarterly = link!(Product.create!(name: "Yoga Trimestrale", price_cents: 12000, duration_days: 90), @yoga_discipline)
    @weights = link!(Product.create!(name: "Sala Pesi Mensile", price_cents: 4000, duration_days: 30), disciplines(:sala_pesi))

    @current = sub(@monthly, Date.current - 25, Date.current + 3)
  end

  def sub(product, start_date, end_date, member: @alice)
    Subscription.create!(member:, product:, start_date:, end_date:)
  end

  test "not renewed by default" do
    assert_not @current.renewed?
    assert_includes Subscription.expiring, @current
  end

  test "renewed with the same product" do
    sub(@monthly, Date.current + 4, Date.current + 34)
    assert @current.renewed?
    assert_not_includes Subscription.expiring, @current
  end

  test "renewed with another product of the same discipline" do
    sub(@quarterly, Date.current + 4, Date.current + 94)
    assert @current.renewed?
  end

  test "another discipline is not a renewal" do
    sub(@weights, Date.current + 4, Date.current + 34)
    assert_not @current.renewed?
  end

  test "another member is not a renewal" do
    sub(@monthly, Date.current + 4, Date.current + 34, member: members(:bob))
    assert_not @current.renewed?
  end

  test "discarded renewal does not count" do
    sub(@monthly, Date.current + 4, Date.current + 34).discard!
    assert_not @current.renewed?
  end

  test "early switch overlapping the end still counts" do
    sub(@quarterly, Date.current, Date.current + 90)
    assert @current.renewed?
  end

  test "older subscription is not a renewal of a newer one" do
    old = sub(@monthly, Date.current - 60, Date.current - 30)
    assert old.renewed?, "il vecchio è rinnovato dal corrente"
    assert_not @current.renewed?
  end

  test "membership renewed by another membership" do
    quota = products(:annual_membership)
    other_quota = Product.create!(name: "Quota Ridotta", price_cents: 1000, duration_days: 365, accounting_category: :associative)
    current = sub(quota, Date.current - 300, Date.current + 2)
    sub(other_quota, Date.current + 3, Date.current + 360)

    assert current.renewed?
  end

  test "status is not expiring once renewed" do
    @current.update_columns(agreed_price_cents: 0)
    assert_equal :expiring_soon, @current.status

    sub(@monthly, Date.current + 4, Date.current + 34)
    assert_equal :active, Subscription.find(@current.id).status
  end

  test "renewal detection is a single query for scopes" do
    sub(@monthly, Date.current + 4, Date.current + 34)
    assert_equal [ @current ], Subscription.renewed.where(member: @alice).to_a
  end

  test "archived members leave the expiring list" do
    @alice.discard!
    assert_not_includes Subscription.expiring, @current
  end

  test "a parallel subscription starting the same day is not a renewal" do
    sub(@quarterly, @current.start_date, @current.end_date + 60)
    assert_not @current.renewed?
  end
end
