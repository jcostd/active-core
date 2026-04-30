require "test_helper"

class SubscriptionLifecycleTest < ActiveSupport::TestCase
  setup do
    @member = members(:alice)
    @user = users(:staff)

    @monthly_course = products(:yoga_monthly)
    # FONDAMENTALE: Assicuriamo che il prodotto sia istituzionale per attivare lo "Snap"
    @monthly_course.update!(duration_days: 30, accounting_category: "institutional")

    @membership_annual = products(:annual_membership)

    grant_membership_to(@member)
  end

  test "Full Chain: Sale -> Issuer -> Subscription -> Duration -> SportYear" do
    # 1. SETUP: Simuliamo un rinnovo intelligente.
    # Usiamo date relative al mese per evitare bug se il test gira il 1° del mese.

    # Mese Scorso: 1° -> Fine Mese
    last_month_start = Date.current.prev_month.beginning_of_month
    last_month_end   = Date.current.prev_month.end_of_month

    # Creiamo il passato (Un abbonamento istituzionale perfetto)
    Subscription.create!(
      member: @member,
      product: @monthly_course,
      sales: [ Sale.create!(member: @member, user: @user, product: @monthly_course, sold_on: last_month_start) ],
      start_date: last_month_start,
      end_date: last_month_end
    )

    # 2. AZIONE: Vendita oggi (sold_on: Today)
    # Supponiamo di essere il 10 del mese corrente.
    # La logica deve capire che è un rinnovo del mese scorso.
    sale = Sale.create!(
      member: @member,
      user: @user,
      product: @monthly_course,
      sold_on: Date.current,
      payment_method: :cash,
      subscription_attributes: { member: @member, product: @monthly_course }
    )

    # 3. VERIFICHE A CASCATA

    # A. SubscriptionIssuer & Duration (Logic Snap)
    # Poiché è un rinnovo continuo di un istituzionale, deve iniziare il 1° di QUESTO mese.
    expected_start = Date.current.beginning_of_month

    assert_equal expected_start, sale.subscription.start_date,
      "Smart Renewal failed: Should snap start date to beginning of current month (#{expected_start})"

    # B. Duration ha lavorato?
    # La data fine deve essere la fine di QUESTO mese.
    expected_end = Date.current.end_of_month

    assert_equal expected_end, sale.subscription.end_date,
      "Duration calculation failed: Should end at the end of the month (#{expected_end})"
  end

  test "The August 31st Wall (Institutional Snap)" do
    travel_to Date.new(2025, 8, 15) do
      sale = Sale.create!(
        member: @member, user: @user, product: @monthly_course,
        sold_on: Date.current,
        subscription_attributes: { member: @member, product: @monthly_course }
      )
      assert_equal Date.new(2025, 8, 1),  sale.subscription.start_date
      assert_equal Date.new(2025, 8, 31), sale.subscription.end_date
    end
  end

  test "Membership Guard: Cannot buy course without active membership" do
    # 1. Creiamo un utente nuovo "pulito" (senza abbonamenti)
    new_guy = Member.create!(
      first_name: "New", last_name: "Guy",
      fiscal_code: "NWGGUY90A01H501X", birth_date: "1990-01-01"
    )

    # 2. Proviamo a vendergli YOGA (Corso Istituzionale)
    # Dovrebbe FALLIRE
    sale = Sale.new(
      member: new_guy,
      user: @user,
      product: @monthly_course, # Yoga
      sold_on: Date.today,
      subscription_attributes: { member: new_guy, product: @monthly_course }
    )

    assert_not sale.save, "Should NOT save sale without membership"
    assert_includes sale.errors[:base].join, "Quota Associativa"

    # 3. Ora gli vendiamo la QUOTA ASSOCIATIVA
    # Dovrebbe PASSARE
    membership_sale = Sale.create!(
      member: new_guy,
      user: @user,
      product: @membership_annual, # Quota 2025
      sold_on: Date.today,
      subscription_attributes: { member: new_guy, product: @membership_annual }
    )
    assert membership_sale.persisted?

    # 4. Riprovasmo a vendergli YOGA
    # Ora dovrebbe PASSARE perché è coperto
    sale_retry = Sale.new(
      member: new_guy,
      user: @user,
      product: @monthly_course,
      sold_on: Date.today,
      subscription_attributes: { member: new_guy, product: @monthly_course }
    )

    assert sale_retry.save!, "Should SAVE sale now that membership exists"
  end
end
