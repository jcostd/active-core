require "test_helper"

class SaleTest < ActiveSupport::TestCase
  setup do
    Sale.delete_all
    ReceiptCounter.delete_all

    @member = members(:bob)
    @user = users(:staff)
    @prod_inst = products(:yoga_monthly)
    @prod_inst.update_columns(
      name: "Yoga Course",
      price_cents: 5000,
      accounting_category: "institutional"
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
    # Leggiamo l'ultimo numero emesso (potrebbe essere > 0 a causa dell'helper grant_membership_to)
    initial_assoc_max = Sale.where(receipt_sequence: "associative").maximum(:receipt_number).to_i

    s1 = Sale.create!(member: @member, product: @prod_inst, user: @user, payment_method: :cash, sold_on: Date.today)
    assert_equal 1, s1.receipt_number
    assert_equal "institutional", s1.receipt_sequence

    s2 = Sale.create!(member: @member, product: @prod_assoc, user: @user, payment_method: :cash, sold_on: Date.today)
    # Assicuriamoci che faccia +1 rispetto a quello che c'era prima
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
    sale = Sale.new(member: @member, product: @prod_inst)
    sale.prepare_draft

    assert_equal Date.current, sale.sold_on
    assert_not_nil sale.subscription
    assert_equal @member, sale.subscription.member
    assert_equal @prod_inst, sale.subscription.product
  end

  test "prepare_draft with manual_start_date forces the subscription start date" do
    sale = Sale.new(member: @member, product: @prod_inst)
    forced_date = 5.days.from_now.to_date

    sale.prepare_draft(manual_start_date: forced_date.to_s)

    assert_equal forced_date, sale.subscription.start_date
  end
end
