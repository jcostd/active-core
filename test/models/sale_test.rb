require "test_helper"

class SaleTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    Sale.delete_all
    ReceiptCounter.delete_all
    Subscription.delete_all

    @member = members(:bob)
    @user = users(:staff)

    @prod_inst = products(:yoga_monthly)
    @prod_inst.update_columns(
      name: "Yoga Course",
      price_cents: 5000,
      accounting_category: "institutional",
      duration_days: 30
    )

    @prod_assoc = products(:annual_membership)
    @prod_assoc.update_columns(
      name: "Tessera 2025",
      price_cents: 2000,
      accounting_category: "associative"
    )

    grant_membership_to(@member)
  end

  # --- TEST FISCALI E DI PAGAMENTO ---

  test "cash payment generates receipt number and year" do
    sale = Sale.create!(
      member: @member, product: @prod_inst, user: @user,
      sold_on: Date.today, payment_method: :cash
    )

    assert sale.cash?
    assert_not_nil sale.receipt_number
    assert_equal 1, sale.receipt_number
    assert_not_nil sale.receipt_year
    assert_equal "institutional", sale.receipt_sequence
  end

  test "credit card payment DOES NOT generate receipt number" do
    sale = Sale.create!(
      member: @member, product: @prod_inst, user: @user,
      sold_on: Date.today, payment_method: :credit_card
    )

    assert sale.credit_card?
    assert_nil sale.receipt_number
    assert_nil sale.receipt_year
    assert_equal "institutional", sale.receipt_sequence
  end

  test "bank transfer payment DOES NOT generate receipt number" do
    sale = Sale.create!(
      member: @member, product: @prod_inst, user: @user,
      sold_on: Date.today, payment_method: :bank_transfer
    )
    assert_nil sale.receipt_number
  end

  test "counting skips non-cash payments correctly" do
    current_year = Date.today.year

    s1 = Sale.create!(member: @member, product: @prod_inst, user: @user, payment_method: :cash, sold_on: Date.today)
    assert_equal 1, s1.receipt_number

    s2 = Sale.create!(member: @member, product: @prod_inst, user: @user, payment_method: :credit_card, sold_on: Date.today)
    assert_nil s2.receipt_number

    s3 = Sale.create!(member: @member, product: @prod_inst, user: @user, payment_method: :cash, sold_on: Date.today)
    assert_equal 2, s3.receipt_number

    assert_equal "#{current_year}-institutional-1", s1.reload.receipt_code
    assert_nil s2.reload.receipt_code
    assert_equal "#{current_year}-institutional-2", s3.reload.receipt_code
  end

  test "sequences are independent even with mixed payments" do
    initial_assoc_max = Sale.where(receipt_sequence: "associative").maximum(:receipt_number).to_i

    s1 = Sale.create!(member: @member, product: @prod_inst, user: @user, payment_method: :cash, sold_on: Date.today)
    assert_equal 1, s1.receipt_number
    assert_equal "institutional", s1.receipt_sequence

    s2 = Sale.create!(member: @member, product: @prod_assoc, user: @user, payment_method: :cash, sold_on: Date.today)
    assert_equal initial_assoc_max + 1, s2.receipt_number
    assert_equal "associative", s2.receipt_sequence

    s3 = Sale.create!(member: @member, product: @prod_inst, user: @user, payment_method: :credit_card, sold_on: Date.today)
    assert_nil s3.receipt_number

    s4 = Sale.create!(member: @member, product: @prod_inst, user: @user, payment_method: :cash, sold_on: Date.today)
    assert_equal 2, s4.receipt_number
  end

  # --- TEST SNAPSHOT E VALUTA ---

  test "snapshots product details on creation" do
    sale = Sale.create!(
      member: @member, product: @prod_inst, user: @user,
      sold_on: Date.today, payment_method: :cash
    )

    assert_equal "Yoga Course", sale.product_name_snapshot
    assert_equal 5000, sale.amount_cents
    assert_equal "institutional", sale.receipt_sequence

    @prod_inst.update!(name: "Yoga New Price", price_cents: 9999)

    sale.reload
    assert_equal "Yoga Course", sale.product_name_snapshot
    assert_equal 5000, sale.amount_cents
  end

  test "monetizable handles strings with italian formatting" do
    sale = Sale.new

    sale.amount = "1.200,50"
    assert_equal 120050, sale.amount_cents
    assert_equal 1200.5, sale.amount

    sale.amount = "50"
    assert_equal 5000, sale.amount_cents

    sale.amount = "12,50"
    assert_equal 1250, sale.amount_cents
  end

  # --- TEST LOGICA DRAFT / FORM LIVE ---

  test "prepare_draft sets sold_on to today if empty and builds subscription" do
    sale = PosDraftBuilder.new(
      sale_params: { member: @member, product: @prod_inst },
      context_params: {}
    ).build

    assert_equal Date.current, sale.sold_on
    assert_not_nil sale.subscription
    assert_equal @member, sale.subscription.member
    assert_equal @prod_inst, sale.subscription.product
  end

  test "prepare_draft with manual_start_date forces the subscription start date" do
    forced_date = 5.days.from_now.to_date

    sale = PosDraftBuilder.new(
      sale_params: { member_id: @member.id, product_id: @prod_inst.id },
      context_params: {
        sale: { subscription_attributes: { start_date: forced_date.to_s } }
      }
    ).build

    assert_equal forced_date, sale.subscription.start_date
  end

  # --- TEST SMART RENEWAL (Ex SubscriptionIssuerTest) ---

  test "creates sale and subscription together (Nested Attributes)" do
    sale_params = {
      member: @member,
      user: @user,
      product: @prod_inst,
      sold_on: Date.current,
      payment_method: :cash,
      subscription_attributes: {
        member: @member,
        product: @prod_inst,
        start_date: Date.current,
        end_date: Date.current + 1.year
      }
    }

    assert_difference [ "Sale.count", "Subscription.count" ], 1 do
      sale = Sale.create!(sale_params)
      assert sale.subscription.present?
      # Verifichiamo la corretta impostazione della relazione "has_many :sales"
      assert_includes sale.subscription.sales, sale
    end
  end

  test "smart renewal: continuity for anticipated renewal snaps to month start" do
    today = Date.new(2025, 1, 20)
    current_expiry = Date.new(2025, 1, 31)

    travel_to today do
      create_past_subscription(end_date: current_expiry)
      sale = create_sale_with_smart_subscription

      expected_start = Date.new(2025, 2, 1)
      expected_end   = Date.new(2025, 2, 28)

      assert_equal expected_start, sale.subscription.start_date
      assert_equal expected_end, sale.subscription.end_date
    end
  end

  test "smart renewal: continuity (punishment) for small gap snaps to gap month start" do
    today = Date.new(2025, 1, 20)
    past_expiry = Date.new(2025, 1, 5)

    travel_to today do
      create_past_subscription(end_date: past_expiry)

      assert_raises(ActiveRecord::RecordInvalid) do
        create_sale_with_smart_subscription
      end
    end
  end

  test "smart renewal: reset to today for huge gap snaps to current month start" do
    today = Date.new(2025, 1, 20)
    past_expiry = Date.new(2024, 10, 31)

    travel_to today do
      create_past_subscription(end_date: past_expiry)
      sale = create_sale_with_smart_subscription

      expected_start = Date.new(2025, 1, 1)
      expected_end   = Date.new(2025, 1, 31)

      assert_equal expected_start, sale.subscription.start_date
      assert_equal expected_end, sale.subscription.end_date
    end
  end

  test "smart renewal: staff manual start date snaps to month start for calendar products" do
    manual_date = Date.new(2025, 1, 15)
    sale_params = default_sale_params
    sale_params[:subscription_attributes][:start_date] = manual_date

    sale = Sale.create!(sale_params)

    expected_start = Date.new(2025, 1, 1)
    expected_end = Date.new(2025, 1, 31)

    assert_equal expected_start, sale.subscription.start_date
    assert_equal expected_end, sale.subscription.end_date
  end

  test "admin override: explicitly providing both dates completely bypasses calculation" do
    start_override = Date.new(2025, 1, 15)
    end_override = Date.new(2025, 3, 10)

    sale_params = default_sale_params
    sale_params[:subscription_attributes][:start_date] = start_override
    sale_params[:subscription_attributes][:end_date] = end_override

    sale = Sale.create!(sale_params)

    assert_equal start_override, sale.subscription.start_date
    assert_equal end_override, sale.subscription.end_date
  end

  # --- TEST SOFT DELETE ---

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
      product: @prod_inst,
      sold_on: Date.current,
      payment_method: :cash,
      subscription_attributes: {
        member: @member,
        product: @prod_inst
      }
    }
  end

  def create_sale_with_smart_subscription
    Sale.create!(default_sale_params)
  end

  def create_past_subscription(end_date:)
    start_date = end_date.beginning_of_month

    Subscription.create!(
      member: @member,
      product: @prod_inst,
      start_date: start_date,
      end_date: end_date,
      sales: [ Sale.create!(member: @member, user: @user, product: @prod_inst, sold_on: start_date) ]
    )
  end
end
