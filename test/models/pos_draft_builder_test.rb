require "test_helper"

class PosDraftBuilderTest < ActiveSupport::TestCase
  setup do
    @member = members(:alice)
    grant_membership_to(@member)
    @course = products(:yoga_monthly)
    @quota  = products(:annual_membership)
  end

  def build(sale: {}, **context)
    PosDraftBuilder.new(sale_params: sale, context_params: { sale: }.merge(context)).build
  end

  test "fresh sale defaults to today, product price and calculated dates" do
    sale = build(sale: { member_id: @member.id, product_id: @course.id })

    assert_equal Date.current, sale.sold_on
    assert_equal @course.price_cents, sale.amount_cents
    assert_equal @course.price_cents, sale.subscription.agreed_price_cents
    assert_equal Duration.for(@course, Date.current).end_date, sale.subscription.end_date
  end

  test "preset member comes from context" do
    sale = build(preset_member_id: @member.id)
    assert_equal @member.id, sale.member_id
  end

  test "renewal starts the day after the old subscription" do
    old = Subscription.create!(member: @member, product: @course, start_date: Date.current.beginning_of_month, end_date: Date.current.end_of_month)

    sale = build(renew_subscription_id: old.id)

    assert_equal @course.id, sale.product_id
    assert_equal @member.id, sale.member_id
    assert_equal old.end_date + 1, sale.subscription.start_date
  end

  test "renewal of an expired subscription starts from today" do
    old = Subscription.create!(member: @member, product: @course, start_date: 3.months.ago.beginning_of_month.to_date, end_date: 3.months.ago.end_of_month.to_date)

    sale = build(renew_subscription_id: old.id)
    assert_equal Date.current.beginning_of_month, sale.subscription.start_date
  end

  test "installment reuses the subscription and proposes the remaining due" do
    first = sell!(member: @member, product: @course, amount: 20)

    sale = build(installment_for_subscription_id: first.subscription_id)

    assert_equal first.subscription, sale.subscription
    assert_equal @course.price_cents - 2000, sale.amount_cents
  end

  test "installment keeps a typed amount" do
    first = sell!(member: @member, product: @course, amount: 20)

    sale = build(sale: { amount: "5" }, installment_for_subscription_id: first.subscription_id)
    assert_equal 500, sale.amount_cents
  end

  test "installment on a discarded subscription is ignored" do
    first = sell!(member: @member, product: @course, amount: 20)
    first.subscription.discard!

    sale = build(installment_for_subscription_id: first.subscription_id)
    assert sale.subscription.new_record?
  end

  test "changing product resets prices and dates" do
    sale = build(sale: { member_id: @member.id, product_id: @quota.id, amount: "45", subscription_attributes: { agreed_price: "45" } },
                 previous_product_id: @course.id, previous_member_id: @member.id)

    assert_equal @quota.price_cents, sale.amount_cents
    assert_equal @quota.price_cents, sale.subscription.agreed_price_cents
  end

  test "same product keeps the typed amount" do
    sale = build(sale: { member_id: @member.id, product_id: @course.id, amount: "12" },
                 previous_product_id: @course.id, previous_member_id: @member.id)
    assert_equal 1200, sale.amount_cents
  end

  test "manual start date is kept as typed" do
    start = Date.current.beginning_of_month + 14
    sale = build(sale: { member_id: @member.id, product_id: @course.id, subscription_attributes: { start_date: start.iso8601 } })
    assert_equal start, sale.subscription.start_date
  end

  test "admin override keeps a manual end date" do
    finish = Date.current + 100
    sale = build(sale: { member_id: @member.id, product_id: @course.id, subscription_attributes: { end_date: finish.iso8601 } },
                 override_end_date: "1")
    assert_equal finish, sale.subscription.end_date
  end
end
