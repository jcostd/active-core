require "test_helper"

class SubscriptionIssuerTest < ActiveSupport::TestCase
  # Usiamo TimeHelpers per bloccare il tempo ed evitare che i test falliscano a fine mese
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @member = members(:alice)
    @user = users(:staff)
    @product = products(:yoga_monthly) # Mensile (30gg) -> Logica Calendario

    grant_membership_to(@member)
  end

  # --- TEST BASE ---

  test "creates sale and subscription together (Nested Attributes)" do
    sale_params = {
      member: @member,
      user: @user,
      product: @product,
      sold_on: Date.current,
      payment_method: :cash,
      subscription_attributes: {
        member: @member,
        product: @product,
        start_date: Date.current,
        end_date: Date.current + 1.year # Manuale: non scatta logica automatica
      }
    }

    assert_difference [ "Sale.count", "Subscription.count" ], 1 do
      sale = Sale.create!(sale_params)
      assert sale.subscription.present?
      assert_equal sale, sale.subscription.sale
    end
  end

  # --- TEST SMART RENEWAL (NUOVA LOGICA CALENDARIO) ---

  test "smart renewal: continuity for anticipated renewal snaps to month start" do
    # Scenario: Oggi è 20 Gennaio.
    # Il vecchio abbonamento scade il 31 Gennaio.
    today = Date.new(2025, 1, 20)
    current_expiry = Date.new(2025, 1, 31)

    travel_to today do
      create_past_subscription(end_date: current_expiry)

      sale = create_sale_with_smart_subscription

      # LOGICA:
      # 1. Fine vecchio: 31 Gennaio.
      # 2. Continuità: 1 Febbraio.
      # 3. Duration Snap: 1 Febbraio è già inizio mese -> OK.

      expected_start = Date.new(2025, 2, 1)
      expected_end   = Date.new(2025, 2, 28)

      assert_equal expected_start, sale.subscription.start_date
      assert_equal expected_end, sale.subscription.end_date
    end
  end

  test "smart renewal: continuity (punishment) for small gap snaps to gap month start" do
    # Scenario: Oggi è 20 Gennaio.
    # Il vecchio abbonamento è scaduto il 5 Gennaio (Buco di 15gg).
    today = Date.new(2025, 1, 20)
    past_expiry = Date.new(2025, 1, 5)

    travel_to today do
      create_past_subscription(end_date: past_expiry)

      sale = create_sale_with_smart_subscription

      # LOGICA:
      # 1. Fine vecchio: 5 Gennaio.
      # 2. Continuità "Punitiva": 6 Gennaio.
      # 3. Duration Snap: Il 6 Gennaio appartiene a Gennaio -> SNAP al 1° Gennaio.

      # Risultato: Il cliente paga per Gennaio intero anche se rinnova il 20.
      expected_start = Date.new(2025, 1, 1)
      expected_end   = Date.new(2025, 1, 31)

      assert_equal expected_start, sale.subscription.start_date
      assert_equal expected_end, sale.subscription.end_date
    end
  end

  test "smart renewal: reset to today for huge gap snaps to current month start" do
    # Scenario: Oggi è 20 Gennaio.
    # Il vecchio abbonamento è scaduto a Ottobre (Buco enorme).
    today = Date.new(2025, 1, 20)
    past_expiry = Date.new(2024, 10, 31)

    travel_to today do
      create_past_subscription(end_date: past_expiry)

      sale = create_sale_with_smart_subscription

      # LOGICA:
      # 1. Buco > Grace Period -> Reset a "Oggi" (20 Gennaio).
      # 2. Duration Snap: Il 20 Gennaio appartiene a Gennaio -> SNAP al 1° Gennaio.

      expected_start = Date.new(2025, 1, 1)
      expected_end   = Date.new(2025, 1, 31)

      assert_equal expected_start, sale.subscription.start_date
      assert_equal expected_end, sale.subscription.end_date
    end
  end

  test "smart renewal: staff manual start date snaps to month start for calendar products" do
    # Scenario: Operatore (Staff) forza inizio al 15 Gennaio dal form.
    manual_date = Date.new(2025, 1, 15)

    sale_params = default_sale_params
    sale_params[:subscription_attributes][:start_date] = manual_date

    sale = Sale.create!(sale_params)

    # 1. Start Date: Duration intercetta il 15 Gennaio e applica lo SNAP
    # al 1° del mese per coprire i giorni antecedenti non pagati (Regola Palestra).
    expected_start = Date.new(2025, 1, 1)

    # 2. End Date: Calcolata da Duration (31 Gennaio).
    expected_end = Date.new(2025, 1, 31)

    assert_equal expected_start, sale.subscription.start_date
    assert_equal expected_end, sale.subscription.end_date
  end

  # AGGIUNGI QUESTO NUOVO TEST per blindare il potere dell'Admin
  test "admin override: explicitly providing both dates completely bypasses calculation" do
    start_override = Date.new(2025, 1, 15)
    end_override = Date.new(2025, 3, 10) # Una data totalmente arbitraria

    sale_params = default_sale_params
    sale_params[:subscription_attributes][:start_date] = start_override
    sale_params[:subscription_attributes][:end_date] = end_override

    sale = Sale.create!(sale_params)

    # Il sistema accetta le date così come sono, senza snappare o ricalcolare nulla
    assert_equal start_override, sale.subscription.start_date
    assert_equal end_override, sale.subscription.end_date
  end

  # --- TEST SOFT DELETE ---
  # Questi rimangono invariati perché testano la logica del DB, non le date.

  test "discarding sale cascades to subscription" do
    sale = create_sale_with_smart_subscription
    subscription = sale.subscription

    sale.discard!
    assert subscription.reload.discarded?
  end

  test "undiscarding sale cascades to subscription" do
    sale = create_sale_with_smart_subscription
    sale.discard!
    sale.undiscard!
    assert_not sale.subscription.reload.discarded?
  end

  private

  def default_sale_params
    {
      member: @member,
      user: @user,
      product: @product,
      sold_on: Date.current,
      payment_method: :cash,
      subscription_attributes: {
        member: @member,
        product: @product
        # start_date/end_date vuote per triggerare smart renewal
      }
    }
  end

  def create_sale_with_smart_subscription
    Sale.create!(default_sale_params)
  end

  def create_past_subscription(end_date:)
    # Creiamo un abbonamento passato "pulito" (es. mese precedente)
    start_date = end_date.beginning_of_month

    Subscription.create!(
      member: @member,
      product: @product,
      start_date: start_date,
      end_date: end_date,
      sale: Sale.create!(member: @member, user: @user, product: @product, sold_on: start_date)
    )
  end
end
