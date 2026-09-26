require "test_helper"

class Sale::FilterableTest < ActiveSupport::TestCase
  setup do
    Sale.delete_all
    @alice = members(:alice)
    grant_membership_to(@alice)
    Sale.delete_all

    @cash  = sell!(member: @alice, product: products(:annual_membership), start_date: 10.years.from_now.to_date)
    @card  = sell!(member: @alice, product: products(:yoga_monthly), payment_method: :credit_card, user: users(:staff_two))
    @old   = sell!(member: @alice, product: products(:yoga_monthly), user: users(:admin), sold_on: 2.months.ago.to_date, start_date: 2.months.ago.to_date)
  end

  test "search by receipt number, member and product" do
    assert_includes Sale.search_text(@cash.receipt_number.to_s), @cash
    assert_equal 3, Sale.search_text("Alice").count
    assert_equal [ @cash ], Sale.search_text("Quota").to_a
  end

  test "filters by payment method, product and operator" do
    assert_equal [ @card ], Sale.by_payment_method("credit_card").to_a
    assert_equal [ @cash ], Sale.by_product(products(:annual_membership).id).to_a
    assert_equal [ @card ], Sale.by_operator(users(:staff_two).id).to_a
  end

  test "filters by period" do
    assert_not_includes Sale.by_period("this_month"), @old
    assert_includes Sale.by_period("last_month").or(Sale.where(id: @old.id)), @old
    assert_equal [ @cash, @card ].sort_by(&:id), Sale.by_period("today").sort_by(&:id)
  end

  test "filters by accounting category" do
    assert_equal [ @cash ], Sale.by_accounting_category("associative").to_a
  end

  test "apply_filters shows kept or discarded" do
    @old.discard!

    assert_not_includes Sale.apply_filters({}), @old
    assert_equal [ @old ], Sale.apply_filters(state: "discarded").to_a
  end

  test "default order is newest sold_on first" do
    assert_equal @old, Sale.apply_filters({}).last
  end

  test "sorted by product name" do
    assert_equal "Quota Associativa 2025", Sale.apply_filters(sort: "name_asc").first.product.name
  end
end
