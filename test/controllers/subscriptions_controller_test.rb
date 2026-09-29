require "test_helper"

class SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = members(:alice)
    grant_membership_to(@member)
    @sub = sell!(member: @member, product: products(:yoga_monthly)).subscription
    sign_in_as(users(:admin))
  end

  test "admin edits dates" do
    get edit_subscription_path(@sub)
    assert_response :success

    patch subscription_path(@sub), params: { subscription: { end_date: (@sub.end_date + 5).iso8601 } }
    assert_redirected_to member_subscriptions_path(@member)
    assert_equal @sub.end_date + 5, @sub.reload.end_date
  end

  test "invalid dates re-render" do
    patch subscription_path(@sub), params: { subscription: { end_date: (@sub.start_date - 1).iso8601 } }
    assert_response :unprocessable_entity
  end

  test "blank agreed price re-renders with a message" do
    patch subscription_path(@sub), params: { subscription: { agreed_price: "" } }

    assert_response :unprocessable_entity
    assert_match "Prezzo concordato", response.body
    assert_equal products(:yoga_monthly).price_cents, @sub.reload.agreed_price_cents
  end

  test "an absurd agreed price re-renders instead of crashing" do
    patch subscription_path(@sub), params: { subscription: { agreed_price: "99999999999999999999" } }

    assert_response :unprocessable_entity
    assert_equal products(:yoga_monthly).price_cents, @sub.reload.agreed_price_cents
  end

  test "saving from the modal refreshes the page under it" do
    patch subscription_path(@sub), params: { subscription: { end_date: (@sub.end_date + 5).iso8601 } }, as: :turbo_stream

    assert_turbo_stream action: :refresh
    assert_equal "Abbonamento aggiornato con successo.", flash[:notice]
  end

  test "raw cents are not accepted from the edit form" do
    patch subscription_path(@sub), params: { subscription: { agreed_price_cents: 1 } }
    assert_equal products(:yoga_monthly).price_cents, @sub.reload.agreed_price_cents
  end

  test "admin writes off a debt by lowering the agreed price" do
    partial = sell!(member: @member, product: products(:yoga_monthly), amount: 10,
                    start_date: Date.current.next_month.beginning_of_month).subscription

    get edit_subscription_path(partial)
    assert_select "input[name='subscription[agreed_price]'][value='45,00']"
    assert_match "Già incassati 10,00", response.body

    patch subscription_path(partial), params: { subscription: { agreed_price: "10,00" } }
    assert_redirected_to member_subscriptions_path(@member)
    assert_equal 1000, partial.reload.agreed_price_cents
    assert_equal 0, partial.amount_due
    assert partial.fully_paid?
    assert_equal [ 1000 ], partial.sales.kept.pluck(:amount_cents), "l'abbuono non tocca i pagamenti"
  end

  test "agreed price cannot go below what was already paid" do
    patch subscription_path(@sub), params: { subscription: { agreed_price: "5" } }

    assert_response :unprocessable_entity
    assert_match "Prezzo concordato non può essere inferiore a quanto già incassato", response.body
    assert_equal products(:yoga_monthly).price_cents, @sub.reload.agreed_price_cents
  end

  test "staff cannot write off a debt" do
    sign_in_as(users(:staff))
    patch subscription_path(@sub), params: { subscription: { agreed_price: "0" } }

    assert_redirected_to root_path
    assert_equal products(:yoga_monthly).price_cents, @sub.reload.agreed_price_cents
  end

  test "an overdue debt shows as insoluto next to an expired badge" do
    old = sell!(member: @member, product: products(:yoga_monthly), amount: 10, user: users(:admin),
                sold_on: Date.current - 70, start_date: Date.current - 70, end_date: Date.current - 40).subscription

    get member_subscriptions_path(@member)
    row = css_select("##{ActionView::RecordIdentifier.dom_id(old)}").to_s
    assert_match "Scaduto", row
    assert_match "Insoluto 35,00", row
    assert_no_match "Da Saldare", row
  end
end
