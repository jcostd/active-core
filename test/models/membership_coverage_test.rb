require "test_helper"

class MembershipCoverageTest < ActiveSupport::TestCase
  setup do
    @alice = members(:alice)
    @quota = products(:annual_membership)
    @monthly = products(:yoga_monthly)
    @quarterly = Product.create!(name: "Yoga Trimestrale", price_cents: 12000, duration_days: 90)
    @yearly = Product.create!(name: "Yoga Annuale", price_cents: 40000, duration_days: 365)
    @admin = users(:admin)
  end

  def membership(year)
    Subscription.create!(member: @alice, product: @quota, start_date: Date.new(year, 9, 1), end_date: Date.new(year + 1, 8, 31))
  end

  def draft(product, start_date, sold_on: Date.current)
    Sale.new(member: @alice, product:, user: @admin, sold_on:,
             subscription_attributes: { member: @alice, product:, start_date: })
  end

  test "coverage chains consecutive memberships" do
    membership(2025)
    membership(2026)
    assert_equal Date.new(2027, 8, 31), @alice.membership_covered_until(Date.new(2026, 1, 10))
  end

  test "coverage stops at a gap" do
    membership(2024)
    membership(2026)
    assert_equal Date.new(2025, 8, 31), @alice.membership_covered_until(Date.new(2025, 1, 10))
    assert_nil @alice.membership_covered_until(Date.new(2025, 10, 1))
  end

  test "course of next sport year needs next year's membership" do
    travel_to Date.new(2026, 8, 25) do
      membership(2025)
      sale = draft(@monthly, Date.new(2026, 9, 1))
      assert_not sale.valid?
      assert_match "non ha una Quota Associativa valida il 01/09/2026", sale.errors.full_messages.to_sentence

      membership(2026)
      assert draft(@monthly, Date.new(2026, 9, 1)).valid?
    end
  end

  test "new member: membership today, monthly course aligned to the first of the month" do
    travel_to Date.new(2026, 9, 26) do
      Subscription.create!(member: @alice, product: @quota, start_date: Date.current, end_date: Date.new(2027, 8, 31))
      assert draft(@monthly, Date.new(2026, 9, 1)).valid?
    end
  end

  test "quarterly crossing the sport year is sold with a warning" do
    travel_to Date.new(2026, 7, 10) do
      membership(2025)
      sale = draft(@quarterly, Date.new(2026, 7, 1))
      sale.subscription.end_date = Duration.for(@quarterly, Date.new(2026, 7, 1)).end_date

      assert sale.valid?, sale.errors.full_messages.to_sentence
      assert_equal "Il corso termina il 30/09/2026, ma la Quota Associativa copre fino al 31/08/2026: " \
                   "il socio dovrà rinnovarla.", sale.membership_warning
    end
  end

  test "no warning when the next membership is already paid" do
    travel_to Date.new(2026, 7, 10) do
      membership(2025)
      membership(2026)
      sale = draft(@quarterly, Date.new(2026, 7, 1))
      sale.subscription.end_date = Date.new(2026, 9, 30)
      assert_nil sale.membership_warning
    end
  end

  test "rolling yearly course warns when crossing the sport year" do
    travel_to Date.new(2026, 1, 15) do
      membership(2025)
      sale = draft(@yearly, Date.new(2026, 1, 15))
      sale.subscription.end_date = Duration.for(@yearly, Date.new(2026, 1, 15)).end_date

      assert_equal Date.new(2027, 1, 14), sale.subscription.end_date
      assert_match "copre fino al 31/08/2026", sale.membership_warning
    end
  end

  test "memberships themselves never warn" do
    sale = Sale.new(member: @alice, product: @quota, user: @admin, sold_on: Date.current,
                    subscription_attributes: { member: @alice, product: @quota, start_date: Date.current, end_date: Date.current + 400 })
    assert_nil sale.membership_warning
  end
end
