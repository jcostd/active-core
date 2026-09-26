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

  test "correctly splits morning and afternoon cash returning floats" do
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

    # Totale Mattina: Solo i 50.00€ (Float)
    assert_in_delta 50.0, cash_report.morning_total
    assert_equal 1, cash_report.morning_sales.count

    # Totale Pomeriggio: Solo i 30.00€ (Float)
    assert_in_delta 30.0, cash_report.afternoon_total
    assert_equal 1, cash_report.afternoon_sales.count

    # Totale Giornata: 80.00€ (Il POS è ignorato)
    assert_in_delta 80.0, cash_report.total

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
    assert_equal 0.0, DailyCash.for(day).total
  end

  test "sales are listed in chronological order" do
    day = Date.current
    late  = at(day, 11, 0) { cash(10) }
    early = at(day, 8, 0)  { cash(10) }

    assert_equal [ early, late ], DailyCash.for(day).morning_sales.to_a
    assert_equal [ early, late ], DailyCash.for(day, sales: [ late, early ]).morning_sales
  end

  private
    def at(day, hour, min, &)
      travel_to(day.in_time_zone.change(hour:, min:), &)
    end

    def cash(euro, payment_method: :cash)
      Sale.create!(member: @member, user: @user, product: @product, sold_on: Date.current, amount: euro,
                   payment_method:, subscription_attributes: { member: @member, product: @product, agreed_price: 100 })
    end
end
