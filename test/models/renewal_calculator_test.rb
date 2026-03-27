require "test_helper"

class RenewalCalculatorTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @member = members(:alice)
    @product = products(:yoga_monthly)
    @member.subscriptions.destroy_all
  end

  test "returns the reference_date if no history exists" do
    today = Date.new(2025, 1, 20)

    travel_to today do
      calculator = RenewalCalculator.new(@member, @product, today)
      suggested_start = calculator.call

      # Senza storico, lo Stratega dice: "Parti dalla data contabile"
      assert_equal today, suggested_start
    end
  end

  test "continuity: anticipated renewal connects to previous end_date" do
    today = Date.new(2025, 1, 20)
    current_expiry = Date.new(2025, 1, 31)

    travel_to today do
      create_past_subscription(end_date: current_expiry)

      calculator = RenewalCalculator.new(@member, @product, today)
      suggested_start = calculator.call

      # Scade il 31, lo Stratega dice: "Parti dal 1° Febbraio"
      assert_equal Date.new(2025, 2, 1), suggested_start
    end
  end

  test "continuity: small gap (grace period) backdates to previous end_date" do
    today = Date.new(2025, 1, 20)
    past_expiry = Date.new(2025, 1, 5) # Gap di 15gg

    travel_to today do
      create_past_subscription(end_date: past_expiry)

      calculator = RenewalCalculator.new(@member, @product, today)
      suggested_start = calculator.call

      # Scaduto da poco, lo Stratega dice: "Recupera il buco, parti dal 6 Gennaio"
      assert_equal Date.new(2025, 1, 6), suggested_start
    end
  end

  test "reset: huge gap starts fresh from reference_date" do
    today = Date.new(2025, 1, 20)
    past_expiry = Date.new(2024, 10, 31) # Gap enorme

    travel_to today do
      create_past_subscription(end_date: past_expiry)

      calculator = RenewalCalculator.new(@member, @product, today)
      suggested_start = calculator.call

      # Buco troppo grosso, lo Stratega dice: "Ricomincia da oggi"
      assert_equal today, suggested_start
    end
  end

  private
    def create_past_subscription(end_date:)
      start_date = end_date.beginning_of_month

      # 1. Creiamo la vendita base
      sale = Sale.create!(member: @member, user: users(:staff), product: @product, sold_on: start_date)

      # 2. Creiamo l'abbonamento (lasciando che Duration calcoli le sue date reali per passare le validazioni)
      sub = Subscription.create!(
        member: @member,
        product: @product,
        sale: sale
      )

      # 3. FORZIAMO la data di fine nel database ignorando le regole,
      # solo per simulare lo scenario di questo specifico test!
      sub.update_columns(end_date: end_date)
    end
end
