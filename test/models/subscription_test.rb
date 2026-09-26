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

    assert_not Subscription.truly_active_at(sale_date).exists?(sub.id)
    assert Subscription.truly_active_at(future_start).exists?(sub.id)
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

  # --- REGOLE DI BASE ---

  test "end date cannot precede start date" do
    sub = Subscription.new(member: @member, product: @prod_inst, start_date: Date.current, end_date: Date.current - 1)
    assert_not sub.valid?
    assert sub.errors[:end_date].any?
  end

  test "overlapping subscriptions for the same product are rejected" do
    Subscription.create!(member: @member, product: @prod_inst, start_date: Date.current, end_date: Date.current + 10)
    dup = Subscription.new(member: @member, product: @prod_inst, start_date: Date.current + 5, end_date: Date.current + 20)

    assert_not dup.valid?
    assert_match "Già un abbonamento", dup.errors.full_messages.to_sentence
  end

  test "overlap ignores discarded subscriptions" do
    Subscription.create!(member: @member, product: @prod_inst, start_date: Date.current, end_date: Date.current + 10).discard!
    assert Subscription.new(member: @member, product: @prod_inst, start_date: Date.current, end_date: Date.current + 10).valid?
  end

  test "negative agreed price is rejected" do
    sub = Subscription.new(member: @member, product: @prod_inst, start_date: Date.current, end_date: Date.current + 1, agreed_price_cents: -1)
    assert_not sub.valid?
  end

  test "entries helpers for unlimited and limited subscriptions" do
    unlimited = Subscription.new(entry_limit: nil, entries_used: 7)
    assert unlimited.unlimited_entries?
    assert_equal 0, unlimited.entries_used
    assert_nil unlimited.entries_remaining
    assert_not unlimited.out_of_entries?

    carnet = Subscription.new(entry_limit: 10, entries_used: 12)
    assert_equal 0, carnet.entries_remaining
    assert carnet.out_of_entries?
  end

  test "expiring_soon excludes future and exhausted subscriptions" do
    assert Subscription.new(start_date: Date.current - 10, end_date: Date.current + 3).expiring_soon?
    assert_not Subscription.new(start_date: Date.current + 1, end_date: Date.current + 3).expiring_soon?
    assert_not Subscription.new(start_date: Date.current - 10, end_date: Date.current + 3, entry_limit: 1, entries_used: 1).expiring_soon?
    assert_not Subscription.new(start_date: Date.current - 10, end_date: Date.current + 30).expiring_soon?
  end

  test "amount paid ignores discarded payments whether loaded or not" do
    sub = Subscription.create!(member: @member, product: @prod_inst, start_date: Date.current, end_date: Date.current + 10, agreed_price_cents: 5000)
    keep = Sale.create!(member: @member, product: @prod_inst, user: @staff, sold_on: Date.current, amount_cents: 1000, subscription: sub)
    Sale.create!(member: @member, product: @prod_inst, user: @staff, sold_on: Date.current, amount_cents: 2000, subscription: sub).discard!

    assert_equal 1000, sub.reload.amount_paid
    assert_equal 1000, Subscription.includes(:sales).find(sub.id).amount_paid
    assert_equal 4000, sub.amount_due
    assert keep.kept?
  end
end
