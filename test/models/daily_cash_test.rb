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
end
