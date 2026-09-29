require "test_helper"

class DailyCashTest < ActiveSupport::TestCase
  setup do
    @member = members(:alice)
    @user = users(:staff)
    @product = products(:yoga_monthly) # Assumiamo prezzo es. 30.0

    # Pulizia preventiva
    Sale.delete_all

    # Setup stato socio (essenziale per vendere corsi)
    grant_membership_to(@member)
    Sale.delete_all # via gli incassi della quota al 1° gennaio: restano solo gli abbonamenti
  end

  test "correctly splits morning and afternoon cash in cents" do
    today = Date.current

    # 1. Vendita MATTINA (ore 10:00) - 50.00 Euro
    travel_to(today.beginning_of_day + 10.hours) do
      Sale.create!(
        member: @member, user: @user, product: @product,
        sold_on: today,
        amount: 50.00, # Usiamo il setter del tuo concern!
        payment_method: :cash,
        subscription_attributes: { member: @member, product: @product, agreed_price: 100.00 }
      )
    end

    # 2. Vendita POMERIGGIO (ore 18:00) - 30.00 Euro
    travel_to(today.beginning_of_day + 18.hours) do
      Sale.create!(
        member: @member, user: @user, product: @product,
        sold_on: today,
        amount: 30.00,
        payment_method: :cash,
        subscription_attributes: { member: @member, product: @product, agreed_price: 100.00 }
      )
    end

    # 3. Vendita POS (ore 11:00) - 100.00 Euro -> NON DEVE ESSERE CONTATA
    travel_to(today.beginning_of_day + 11.hours) do
      Sale.create!(
        member: @member, user: @user, product: @product,
        sold_on: today,
        amount: 100.00,
        payment_method: :credit_card,
        subscription_attributes: { member: @member, product: @product, agreed_price: 100.00 }
      )
    end

    # --- VERIFICA ---
    # Istanziamo il report
    cash_report = DailyCash.new(today)

    assert_equal 5000, cash_report.morning_cents
    assert_equal 1, cash_report.morning_sales.count

    assert_equal 3000, cash_report.afternoon_cents
    assert_equal 1, cash_report.afternoon_sales.count

    # il POS è ignorato
    assert_equal 8000, cash_report.total_cents

    # Verifica che non sia vuoto
    assert_not cash_report.empty?
  end

  test "split is at 14:00 Rome time" do
    day = Date.current
    at(day, 13, 59) { cash(10) }
    at(day, 14, 0)  { cash(20) }

    report = DailyCash.for(day)
    assert_equal 1000, report.morning_cents
    assert_equal 2000, report.afternoon_cents
  end

  test "preloaded sales give the same totals as the database" do
    day = Date.current
    at(day, 9, 0)  { cash(10) }
    at(day, 17, 0) { cash(25) }

    from_db = DailyCash.for(day)
    preloaded = DailyCash.for(day, sales: Sale.kept.where(sold_on: day, payment_method: :cash).to_a)

    assert_equal [ from_db.morning_cents, from_db.afternoon_cents, from_db.total_cents, from_db.count ],
                 [ preloaded.morning_cents, preloaded.afternoon_cents, preloaded.total_cents, preloaded.count ]
  end

  test "discarded and non cash sales are excluded" do
    day = Date.current
    at(day, 9, 0) { cash(10).discard! }
    at(day, 9, 0) { cash(15, payment_method: :bank_transfer) }

    assert DailyCash.for(day).empty?
    assert_equal 0, DailyCash.for(day).total_cents
  end

  test "sales are listed in chronological order" do
    day = Date.current
    late  = at(day, 11, 0) { cash(10) }
    early = at(day, 8, 0)  { cash(10) }

    assert_equal [ early, late ], DailyCash.for(day).morning_sales.to_a
    assert_equal [ early, late ], DailyCash.for(day, sales: [ late, early ]).morning_sales
  end

  test "sales registered on another day count in the total but in no shift" do
    yesterday = Date.current - 1
    at(yesterday, 9, 0) { cash(10, sold_on: yesterday) }
    at(Date.current, 10, 0) { cash(7, sold_on: yesterday, user: users(:admin)) }

    report = DailyCash.for(yesterday)
    assert_equal [ 1000, 0, 700, 1700 ], [ report.morning_cents, report.afternoon_cents, report.late_cents, report.total_cents ]
    assert_equal 1, report.late_sales.size
    assert_equal report.total_cents, report.morning_cents + report.afternoon_cents + report.late_cents
  end

  test "a late sale does not leak into the day it was registered" do
    yesterday = Date.current - 1
    at(Date.current, 10, 0) { cash(7, sold_on: yesterday, user: users(:admin)) }

    assert DailyCash.for(Date.current).empty?
    assert_equal 0, DailyCash.for(Date.current).morning_cents
  end

  test "shifts follow Rome time, not UTC, at midnight" do
    day = Date.current
    at(day, 0, 30) { cash(4) } # 23:30 UTC del giorno prima (o 22:30 in estate)

    report = DailyCash.for(day)
    assert_equal 400, report.morning_cents
    assert_empty report.late_sales
  end

  test "preloaded sales classify late ones like the database" do
    yesterday = Date.current - 1
    at(yesterday, 16, 0) { cash(10, sold_on: yesterday) }
    at(Date.current, 10, 0) { cash(7, sold_on: yesterday, user: users(:admin)) }

    from_db = DailyCash.for(yesterday)
    preloaded = DailyCash.for(yesterday, sales: Sale.kept.where(sold_on: yesterday, payment_method: :cash).reverse)
    assert_equal [ from_db.afternoon_cents, from_db.late_cents ], [ preloaded.afternoon_cents, preloaded.late_cents ]
  end

  private
    def at(day, hour, min, &)
      travel_to(day.in_time_zone.change(hour:, min:), &)
    end

    def cash(euro, payment_method: :cash, sold_on: Date.current, user: @user)
      Sale.create!(member: @member, user:, product: @product, sold_on:, amount: euro,
                   payment_method:, subscription_attributes: { member: @member, product: @product, agreed_price: 100 })
    end
end
