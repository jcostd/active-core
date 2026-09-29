require "test_helper"

class Product::FilterableTest < ActiveSupport::TestCase
  test "excludes discarded products" do
    assert_not_includes Product.apply_filters({}), products(:pilates_legacy)
  end

  test "search by name" do
    assert_equal [ products(:yoga_monthly) ], Product.apply_filters(query: "yoga").to_a
  end

  test "filters by accounting category" do
    assert_equal [ products(:annual_membership) ], Product.apply_filters(accounting_category: "associative").to_a
    assert_equal Product.kept.count, Product.apply_filters(accounting_category: "bogus").count
  end

  test "sorts by name, newest first by default" do
    assert_equal products(:annual_membership), Product.apply_filters(sort: "name_asc").first
    assert_equal products(:yoga_monthly), Product.apply_filters(sort: "name_desc").first

    travel 1.second # con TEST_NOW il tempo è fermo: niente pareggi su created_at
    newest = Product.create!(name: "Nuovo", price_cents: 1, duration_days: 30)
    assert_equal newest, Product.apply_filters({}).first
    assert_equal newest, Product.apply_filters(sort: "'; DROP TABLE products; --").first
  end
end
