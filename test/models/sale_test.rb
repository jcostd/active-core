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

  test "payment method defaults to card in the model, never to an invalid database value" do
    assert_nil Sale.columns_hash["payment_method"].default
    assert_equal "credit_card", Sale.new.payment_method
  end

  test "unknown payment method is a validation error" do
    sale = Sale.new(payment_method: "bitcoin")
    assert_not sale.valid?
    assert sale.errors[:payment_method].any?
  end

  test "cash payment generates receipt number and year" do
    sale = Sale.create!(
      member: @member, product: @prod_inst, user: @user,
      sold_on: Date.current, payment_method: :cash
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
      sold_on: Date.current, payment_method: :credit_card
    )

    assert sale.credit_card?
    assert_nil sale.receipt_number
    assert_nil sale.receipt_year
    assert_equal "institutional", sale.receipt_sequence
  end

  test "bank transfer payment DOES NOT generate receipt number" do
    sale = Sale.create!(
      member: @member, product: @prod_inst, user: @user,
      sold_on: Date.current, payment_method: :bank_transfer
    )
    assert_nil sale.receipt_number
  end

  test "counting skips non-cash payments correctly" do
    current_year = Date.current.year

    s1 = Sale.create!(member: @member, product: @prod_inst, user: @user, payment_method: :cash, sold_on: Date.current)
    assert_equal 1, s1.receipt_number

    s2 = Sale.create!(member: @member, product: @prod_inst, user: @user, payment_method: :credit_card, sold_on: Date.current)
    assert_nil s2.receipt_number

    s3 = Sale.create!(member: @member, product: @prod_inst, user: @user, payment_method: :cash, sold_on: Date.current)
    assert_equal 2, s3.receipt_number

    assert_equal "#{current_year}-institutional-1", s1.reload.receipt_code
    assert_nil s2.reload.receipt_code
    assert_equal "#{current_year}-institutional-2", s3.reload.receipt_code
  end

  test "sequences are independent even with mixed payments" do
    initial_assoc_max = Sale.where(receipt_sequence: "associative").maximum(:receipt_number).to_i

    s1 = Sale.create!(member: @member, product: @prod_inst, user: @user, payment_method: :cash, sold_on: Date.current)
    assert_equal 1, s1.receipt_number
    assert_equal "institutional", s1.receipt_sequence

    s2 = Sale.create!(member: @member, product: @prod_assoc, user: @user, payment_method: :cash, sold_on: Date.current)
    assert_equal initial_assoc_max + 1, s2.receipt_number
    assert_equal "associative", s2.receipt_sequence

    s3 = Sale.create!(member: @member, product: @prod_inst, user: @user, payment_method: :credit_card, sold_on: Date.current)
    assert_nil s3.receipt_number

    s4 = Sale.create!(member: @member, product: @prod_inst, user: @user, payment_method: :cash, sold_on: Date.current)
    assert_equal 2, s4.receipt_number
  end

  # --- TEST SNAPSHOT E VALUTA ---

  test "snapshots product details on creation" do
    sale = Sale.create!(
      member: @member, product: @prod_inst, user: @user,
      sold_on: Date.current, payment_method: :cash
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
    sale = Sale::Draft.new(Sale.new(member: @member, product: @prod_inst)).sale

    assert_equal Date.current, sale.sold_on
    assert_not_nil sale.subscription
    assert_equal @member, sale.subscription.member
    assert_equal @prod_inst, sale.subscription.product
  end

  test "prepare_draft with manual_start_date forces the subscription start date" do
    forced_date = 5.days.from_now.to_date

    sale = Sale::Draft.new(Sale.new(member_id: @member.id, product_id: @prod_inst.id,
                                    subscription_attributes: { start_date: forced_date.to_s })).sale

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

  test "smart renewal: manual start date snaps to month start for calendar products" do
    manual_date = Date.new(2025, 1, 15)
    grant_membership_to(@member, start_date: manual_date)
    sale_params = default_sale_params.merge(user: users(:admin))
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
    grant_membership_to(@member, start_date: start_override)

    sale_params = default_sale_params.merge(user: users(:admin))
    sale_params[:subscription_attributes][:start_date] = start_override
    sale_params[:subscription_attributes][:end_date] = end_override

    sale = Sale.create!(sale_params)

    assert_equal start_override, sale.subscription.start_date
    assert_equal end_override, sale.subscription.end_date
  end

  # --- TEST ARCHIVIAZIONE ---

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

  # --- RATE ---

  test "progressive installments recompute amount due until fully paid" do
    first = sell_course(amount: 12.34)
    sub = first.subscription

    assert_equal 5000, sub.agreed_price_cents
    assert_equal 5000 - 1234, sub.amount_due
    assert_not sub.fully_paid?

    pay_installment(sub, amount: 20)
    assert_equal 5000 - 1234 - 2000, sub.reload.amount_due

    last = pay_installment(sub)
    assert_equal 5000 - 1234 - 2000, last.amount_cents, "defaults to remaining due"
    assert_equal 0, sub.reload.amount_due
    assert sub.fully_paid?
  end

  test "installment cannot exceed remaining due" do
    sub = sell_course(amount: 40).subscription

    sale = build_installment(sub, amount: 10.01)
    assert_not sale.valid?
    assert_includes sale.errors[:amount].join, "10,00"
  end

  test "first payment cannot exceed agreed price" do
    sale = Sale.new(member: @member, product: @prod_inst, user: @user, sold_on: Date.current,
                    amount: 50.01, subscription_attributes: { member: @member, product: @prod_inst })
    assert_not sale.valid?
    assert sale.errors[:amount].any?
  end

  test "installment cannot be zero, not even for admin" do
    sub = sell_course(amount: 10).subscription

    sale = build_installment(sub, amount: 0, user: users(:admin))
    assert_not sale.valid?
  end

  test "discarded installment frees its amount again" do
    sub = sell_course(amount: 10).subscription
    rata = pay_installment(sub, amount: 15)

    rata.discard!
    assert_equal 4000, sub.reload.amount_due
  end

  test "installment is accepted after membership expired" do
    sub = sell_course(amount: 10).subscription

    travel_to 5.years.from_now do
      assert_not @member.membership_valid?
      assert build_installment(sub, amount: 10).valid?
    end
  end

  test "installment on a discarded subscription is rejected" do
    sub = sell_course(amount: 10).subscription
    sub.discard!

    assert_not build_installment(sub, amount: 10).valid?
  end

  # --- IMPORTO ZERO ---

  test "staff cannot register a zero sale" do
    sale = Sale.new(member: @member, product: @prod_inst, user: @user, sold_on: Date.current,
                    amount: 0, subscription_attributes: { member: @member, product: @prod_inst })
    assert_not sale.valid?
    assert_includes sale.errors[:base].join, "amministratore"
  end

  test "admin can register a free sale with zero agreed price" do
    sale = Sale.create!(member: @member, product: @prod_inst, user: users(:admin), sold_on: Date.current,
                        amount: 0, subscription_attributes: { member: @member, product: @prod_inst, agreed_price: 0 })

    assert_equal 0, sale.amount_cents
    assert_equal 0, sale.subscription.agreed_price_cents
    assert sale.subscription.fully_paid?
  end

  test "blank amount defaults to product price" do
    sale = sell_course(amount: nil)
    assert_equal 5000, sale.amount_cents
  end

  # --- APPARTENENZA DELL'ABBONAMENTO ---

  test "sale cannot pay another member subscription" do
    other = members(:alice)
    grant_membership_to(other)
    sub = sell_course(amount: 10).subscription

    sale = Sale.new(member: other, product: @prod_inst, user: @user, sold_on: Date.current, amount: 10, subscription: sub)
    assert_not sale.valid?
    assert sale.errors[:subscription].any?
  end

  test "sale product must match subscription product" do
    sub = sell_course(amount: 10).subscription

    sale = build_installment(sub, amount: 10)
    sale.product = @prod_assoc
    assert_not sale.valid?
    assert sale.errors[:subscription].any?
  end

  # --- ANNULLAMENTO ---

  test "staff reverses own sale within the staff window" do
    sale = sell_course(amount: 10)

    travel Sale::STAFF_REVERSAL_WINDOW - 1.minute
    assert sale.reversible_by?(@user)

    travel 2.minutes
    assert_not sale.reversible_by?(@user)
  end

  test "staff cannot reverse a colleague sale" do
    sale = sell_course(amount: 10)
    assert_not sale.reversible_by?(users(:staff_two))
  end

  test "admin reverses any sale within the admin window" do
    sale = sell_course(amount: 10)

    travel Sale::ADMIN_REVERSAL_WINDOW - 1.minute
    assert sale.reversible_by?(users(:admin))

    travel 2.minutes
    assert_not sale.reversible_by?(users(:admin))
  end

  test "discarded sale is not reversible again" do
    sale = sell_course(amount: 10)
    sale.discard!
    assert_not sale.reversible_by?(users(:admin))
  end

  # --- CASCATA SULL'ABBONAMENTO ---

  test "discarding a subscription annuls all its payments" do
    sub = sell_course(amount: 10).subscription
    pay_installment(sub, amount: 15)

    sub.discard!

    assert sub.sales.reload.all?(&:discarded?)
    assert_equal 2, sub.sales.count
  end

  test "subscription cascade is atomic" do
    sub = sell_course(amount: 10).subscription
    pay_installment(sub, amount: 15)
    conn = Sale.connection
    conn.execute(<<~SQL)
      CREATE TEMP TRIGGER fail_second_payment BEFORE UPDATE OF discarded_at ON sales
      WHEN NEW.amount_cents = 1500 BEGIN SELECT RAISE(ABORT, 'boom'); END
    SQL

    assert_raises(ActiveRecord::StatementInvalid) { sub.discard! }
    assert sub.reload.kept?
    assert sub.sales.reload.none?(&:discarded?)
  ensure
    conn&.execute("DROP TRIGGER IF EXISTS temp.fail_second_payment")
  end

  test "aborted discard raises" do
    sale = sell_course(amount: 10)
    sale.define_singleton_method(:run_callbacks) { |*| false }

    assert_raises(ActiveRecord::RecordNotSaved) { sale.discard! }
  end

  test "staff discards own fresh subscription" do
    sub = sell_course(amount: 10).subscription
    assert sub.discardable_by?(@user)
    assert_not sub.discardable_by?(users(:staff_two))
  end

  test "subscription with a colleague payment is not discardable by staff" do
    sub = sell_course(amount: 10).subscription
    pay_installment(sub, amount: 10, user: users(:staff_two))

    assert_not sub.discardable_by?(@user)
    assert_not sub.discardable_by?(users(:staff_two))
    assert sub.discardable_by?(users(:admin))
  end

  test "subscription follows the oldest payment window" do
    sub = sell_course(amount: 10).subscription
    travel Sale::ADMIN_REVERSAL_WINDOW - 1.hour
    pay_installment(sub, amount: 10)

    travel 2.hours
    assert_not sub.reload.discardable_by?(users(:admin))
  end

  test "subscription without payments is discardable by admin only" do
    sub = Subscription.create!(member: @member, product: @prod_inst, start_date: Date.current)

    assert sub.discardable_by?(users(:admin))
    assert_not sub.discardable_by?(@user)
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
    grant_membership_to(@member) # le date fisse (2025) possono cadere fuori da quelle del setup con TEST_NOW
    Sale.create!(default_sale_params)
  end

  def create_past_subscription(end_date:)
    start_date = end_date.beginning_of_month

    Subscription.create!(
      member: @member,
      product: @prod_inst,
      start_date: start_date,
      end_date: end_date,
      sales: [ Sale.create!(member: @member, user: users(:admin), product: @prod_inst, sold_on: start_date) ]
    )
  end

  def sell_course(amount:)
    Sale.create!(member: @member, product: @prod_inst, user: @user, sold_on: Date.current,
                 amount:, subscription_attributes: { member: @member, product: @prod_inst })
  end

  def build_installment(sub, amount: nil, user: @user)
    Sale.new(member: sub.member, product: sub.product, user:, sold_on: Date.current, amount:, subscription: sub)
  end

  def pay_installment(sub, **)
    build_installment(sub, **).tap(&:save!)
  end

  # --- ARCHIVIATI ---

  test "no new sale to an archived member" do
    @member.discard!
    sale = Sale.new(member: @member, product: @prod_inst, user: @user, sold_on: Date.current,
                    subscription_attributes: { member: @member, product: @prod_inst })
    assert_not sale.valid?
    assert_includes sale.errors.full_messages, "Socio è archiviato"
  end

  test "no new sale of an archived product" do
    @prod_inst.discard!
    sale = Sale.new(member: @member, product: @prod_inst, user: @user, sold_on: Date.current,
                    subscription_attributes: { member: @member, product: @prod_inst })
    assert_not sale.valid?
    assert_includes sale.errors.full_messages, "Prodotto è archiviato"
  end

  test "installments stay payable after archiving the product" do
    sub = sell_course(amount: 10).subscription
    @prod_inst.discard!

    assert build_installment(sub, amount: 10).valid?
  end

  test "staff can register a free product" do
    trial = Product.create!(name: "Prova Gratuita", price_cents: 0, duration_days: 7)
    sale = Sale.create!(member: @member, product: trial, user: @user, sold_on: Date.current,
                        subscription_attributes: { member: @member, product: trial })

    assert_equal 0, sale.amount_cents
    assert sale.subscription.fully_paid?
  end

  test "staff still cannot zero a paid product" do
    sale = Sale.new(member: @member, product: @prod_inst, user: @user, sold_on: Date.current, amount: 0,
                    subscription_attributes: { member: @member, product: @prod_inst })
    assert_not sale.valid?
  end

  # --- DATE NEL POS ---

  test "staff cannot backdate the accounting date" do
    sale = Sale.new(default_sale_params.merge(sold_on: Date.current - 1))
    assert_not sale.valid?
    assert_includes sale.errors.full_messages, "Data contabile può essere modificata solo da un amministratore"
  end

  test "admin can backdate the accounting date" do
    assert Sale.new(default_sale_params.merge(user: users(:admin), sold_on: Date.current - 40)).valid?
  end

  test "accounting date defaults to today" do
    sale = Sale.create!(default_sale_params.except(:sold_on))
    assert_equal Date.current, sale.sold_on
  end

  test "staff can only move the start forward" do
    proposed = @member.next_period_for(@prod_inst).start_date

    earlier = Sale.new(default_sale_params.deep_merge(subscription_attributes: { start_date: proposed - 1 }))
    assert_not earlier.valid?
    assert_includes earlier.errors.full_messages, "Abbonamento può iniziare al più presto il #{I18n.l(proposed)}"

    later = Sale.new(default_sale_params.deep_merge(subscription_attributes: { start_date: proposed.next_month.beginning_of_month }))
    assert later.valid?, later.errors.full_messages.to_sentence
  end

  test "admin can start earlier than proposed" do
    proposed = @member.next_period_for(@prod_inst).start_date
    sale = Sale.new(default_sale_params.merge(user: users(:admin)).deep_merge(subscription_attributes: { start_date: proposed - 40 }))
    assert sale.valid?, sale.errors.full_messages.to_sentence
  end

  test "installments are not bound to the start rule" do
    sub = sell_course(amount: 10).subscription
    sub.update_columns(start_date: Date.current - 60)
    assert build_installment(sub, amount: 10).valid?
  end
end
