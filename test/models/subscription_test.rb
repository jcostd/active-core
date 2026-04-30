require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  setup do
    Subscription.delete_all
    Sale.delete_all

    @member = members(:bob)
    @staff = users(:staff)

    grant_membership_to(@member)

    @prod_inst = products(:yoga_monthly)
    # Institutional -> Forza allineamento al mese solare
    @prod_inst.update!(duration_days: 30, accounting_category: "institutional")
  end

  test "automatically calculates dates based on sale date (Institutional Snap)" do
    # Scenario: Vendita fatta il 20 Gennaio
    sale_date = Date.new(2025, 1, 20)

    sale = Sale.create!(
      member: @member,
      user: users(:staff),
      product: @prod_inst,
      sold_on: sale_date,
      subscription_attributes: { member: @member, product: @prod_inst }
    )

    sub = sale.subscription

    # CORREZIONE: Essendo istituzionale, il 20 Gennaio diventa 1° Gennaio
    assert_equal Date.new(2025, 1, 1), sub.start_date

    # CORREZIONE: La fine è fine mese
    assert_equal Date.new(2025, 1, 31), sub.end_date
  end

  test "respects user preference for future start date" do
    # Scenario: Oggi 20 Gennaio, ma voglio iniziare a Febbraio
    sale_date = Date.new(2025, 1, 20)
    future_start = Date.new(2025, 2, 1) # Già primo del mese

    sale = Sale.create!(
      member: @member, product: @prod_inst, user: @staff,
      sold_on: sale_date, payment_method: :cash
    )

    sub = Subscription.create!(
      member: @member, product: @prod_inst, sales: [ sale ],
      start_date: future_start
    )

    assert_equal Date.new(2025, 2, 1), sub.start_date
    assert_equal Date.new(2025, 2, 28), sub.end_date

    assert_not sub.active?(sale_date)
    assert sub.active?(future_start)
  end

  test "scopes filter correctly" do
    today = Date.current
    sale = Sale.create!(member: @member, product: @prod_inst, user: @staff, sold_on: today)

    # 1. Scaduto
    expired = Subscription.create!(
      member: @member, product: @prod_inst, sales: [ sale ],
      start_date: today - 2.months, end_date: today - 1.month
    )

    # 2. Attivo
    active = Subscription.create!(
      member: @member, product: @prod_inst, sales: [ sale ],
      start_date: today.beginning_of_month, end_date: today.end_of_month
    )

    # 3. Futuro
    upcoming = Subscription.create!(
      member: @member, product: @prod_inst, sales: [ sale ],
      start_date: today + 1.month, end_date: today + 2.months
    )

    assert_includes Subscription.active, active
    assert_not_includes Subscription.active, expired
    assert_not_includes Subscription.active, upcoming

    assert_includes Subscription.expired, expired
    assert_includes Subscription.upcoming, upcoming
  end

  test "admin override: prevents Duration calculator from modifying explicitly provided end_dates" do
    invalid_end_date = Date.current + 50.days

    sale = Sale.create!(member: @member, product: @prod_inst, user: @staff, sold_on: Date.current)

    subscription = Subscription.new(
      member: @member,
      product: @prod_inst,
      sales: [ sale ],
      start_date: Date.current,
      end_date: invalid_end_date
    )

    subscription.valid?

    assert_equal invalid_end_date, subscription.end_date
  end
end
