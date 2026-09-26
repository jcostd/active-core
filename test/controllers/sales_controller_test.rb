require "test_helper"

class SalesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @staff  = users(:staff)
    @admin  = users(:admin)
    @member = members(:bob)
    @course = products(:yoga_monthly)

    grant_membership_to(@member)
    @sale = Sale.create!(member: @member, product: @course, user: @staff, sold_on: Date.current,
                         amount: 10, subscription_attributes: { member: @member, product: @course })
  end

  test "staff reverses own sale within the window" do
    sign_in_as(@staff)

    delete sale_path(@sale)

    assert @sale.reload.discarded?
    assert @sale.subscription.reload.discarded?, "unico pagamento: si annulla anche l'abbonamento"
    assert_equal "Pagamento annullato.", flash[:notice]
  end

  test "staff cannot reverse own sale after the window" do
    travel Sale::STAFF_REVERSAL_WINDOW + 1.minute
    sign_in_as(@staff)

    delete sale_path(@sale)

    assert @sale.reload.kept?
    assert_equal "Questo pagamento non è più annullabile.", flash[:alert]
  end

  test "staff cannot reverse a colleague sale" do
    sign_in_as(users(:staff_two))

    delete sale_path(@sale)

    assert @sale.reload.kept?
  end

  test "sale page offers undo only to who can use it" do
    sign_in_as(@staff)
    get sale_path(@sale)
    assert_select "a", text: /Annulla Pagamento/

    sign_out
    sign_in_as(users(:staff_two))
    get sale_path(@sale)
    assert_select "a", text: /Annulla Pagamento/, count: 0
  end

  test "admin reverses a recent sale" do
    sign_in_as(@admin)

    delete sale_path(@sale)

    assert @sale.reload.discarded?
  end

  test "admin cannot reverse after the window" do
    travel_to (Sale::ADMIN_REVERSAL_WINDOW + 1.minute).from_now do
      sign_in_as(@admin)

      delete sale_path(@sale)

      assert @sale.reload.kept?
    end
  end

  test "staff cashes an arbitrary installment" do
    sign_in_as(@staff)
    sub = @sale.subscription

    assert_difference -> { Sale.count } do
      post sales_path, params: { sale: { member_id: @member.id, product_id: @course.id, subscription_id: sub.id,
                                         amount: "7,50", payment_method: "cash", sold_on: Date.current } }
    end
    assert_equal 4500 - 1000 - 750, sub.reload.amount_due
  end

  test "staff agreed price is ignored" do
    sign_in_as(@staff)
    alice = members(:alice)
    grant_membership_to(alice)

    post sales_path, params: { sale: { member_id: alice.id, product_id: @course.id, amount: "5", payment_method: "cash",
                                       sold_on: Date.current, subscription_attributes: { start_date: Date.current, agreed_price: "0" } } }

    assert_response :redirect
    assert_equal @course.price_cents, Sale.last.subscription.agreed_price_cents
  end

  test "staff discards own fresh subscription with its payments" do
    sign_in_as(@staff)

    delete subscription_path(@sale.subscription)

    assert @sale.subscription.reload.discarded?
    assert @sale.reload.discarded?
    assert_equal "Abbonamento e pagamenti collegati annullati.", flash[:notice]
  end

  test "staff cannot discard a colleague subscription" do
    sign_in_as(users(:staff_two))

    delete subscription_path(@sale.subscription)

    assert @sale.subscription.reload.kept?
    assert @sale.reload.kept?
    assert_equal "Questo abbonamento non è più annullabile.", flash[:alert]
  end

  test "admin cannot discard a subscription with old payments" do
    travel Sale::ADMIN_REVERSAL_WINDOW + 1.minute
    sign_in_as(@admin)

    delete subscription_path(@sale.subscription)

    assert @sale.subscription.reload.kept?
  end

  test "admin zero draft is kept by the POS builder" do
    sign_in_as(@admin)
    alice = members(:alice)

    get new_sale_path, params: { sale: { member_id: alice.id, product_id: @course.id, amount: "0",
                                         subscription_attributes: { agreed_price: "0" } },
                                 previous_member_id: alice.id, previous_product_id: @course.id }

    assert_response :success
    assert_select "input[name='sale[amount]'][value='0.0']"
  end

  # --- FORM POS ---

  test "new sale form renders for a member" do
    sign_in_as(@staff)
    get new_sale_path(member_id: @member.id)
    assert_response :success
    assert_select "form#new_sale, form[action='#{new_sale_path}']"
  end

  test "renewal form proposes the day after the old subscription" do
    sign_in_as(@staff)
    old = @sale.subscription

    get new_sale_path(member_id: @member.id, renew_subscription_id: old.id)
    assert_response :success
    assert_select "input[name='sale[subscription_attributes][start_date]'][value='#{(old.end_date + 1).iso8601}']"
  end

  test "installment form shows paid and remaining amounts" do
    sign_in_as(@staff)

    get new_sale_path(member_id: @member.id, installment_for_subscription_id: @sale.subscription_id)
    assert_response :success
    assert_match "Incassa Rata", response.body
    assert_select "input[name='sale[amount]'][value='35.0']"
  end

  test "overpaying an installment re-renders with an italian error" do
    sign_in_as(@staff)

    assert_no_difference -> { Sale.count } do
      post sales_path, params: { sale: { member_id: @member.id, product_id: @course.id, subscription_id: @sale.subscription_id,
                                         amount: "50", payment_method: "cash", sold_on: Date.current } }
    end
    assert_response :unprocessable_entity
    assert_match "Importo supera il residuo dovuto (35,00 €)", response.body
  end

  test "course sale without membership is refused" do
    sign_in_as(@staff)
    alice = members(:alice) # nessuna quota

    assert_no_difference -> { Sale.count } do
      post sales_path, params: { sale: { member_id: alice.id, product_id: @course.id, amount: "45", payment_method: "cash",
                                         sold_on: Date.current, subscription_attributes: { start_date: Date.current } } }
    end
    assert_match "non avrà una Quota Associativa attiva", response.body
  end

  test "successful sale redirects to the sale page" do
    sign_in_as(@staff)
    alice = members(:alice)
    grant_membership_to(alice)

    post sales_path, params: { sale: { member_id: alice.id, product_id: @course.id, amount: "45", payment_method: "cash",
                                       sold_on: Date.current, subscription_attributes: { start_date: Date.current } } }
    sale = Sale.order(:id).last
    assert_redirected_to sale_path(sale)
    assert_equal users(:staff), sale.user
    assert_equal "Vendita registrata con successo.", flash[:notice]
  end

  test "sale page and pdf" do
    sign_in_as(@staff)

    get sale_path(@sale)
    assert_response :success
    assert_match @course.name, response.body

    get sale_path(@sale, format: :pdf)
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF")
    assert_match "ricevuta_#{@sale.id}_Bianchi.pdf", response.headers["Content-Disposition"]
  end

  test "admin sales list with filters" do
    sign_in_as(@admin)

    get sales_path(payment_method: "credit_card", period: "today", query: "Bianchi")
    assert_response :success
    assert_match "Bob Bianchi", response.body

    get sales_path(payment_method: "bank_transfer")
    assert_no_match "Bob Bianchi", response.body
  end
end
