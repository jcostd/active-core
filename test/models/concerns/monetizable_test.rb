require "test_helper"

class MonetizableTest < ActiveSupport::TestCase
  test "converts cents to float for reading" do
    product = Product.new(price_cents: 1050) # 10.50 €
    assert_equal 10.50, product.price
  end

  test "handles comma as decimal separator" do
    product = Product.new
    product.price = "10,50" # Input "Italiano"

    assert_equal 1050, product.price_cents
    assert_equal 10.50, product.price
  end

  test "handles dot as decimal separator" do
    product = Product.new
    product.price = "10.50" # Input "USA" (punto decimale)

    assert_equal 1050, product.price_cents
  end

  test "cleans dirty input" do
    product = Product.new
    product.price = "€ 1.200,50" # Input sporco con valuta

    # 1200.50 * 100 = 120050
    assert_equal 120050, product.price_cents
  end

  test "handles nil and empty strings gracefully" do
    product = Product.new

    product.price = nil
    assert_nil product.price_cents

    product.price = ""
    assert_nil product.price_cents
  end

  test "handles numeric input (not string)" do
    product = Product.new
    product.price = 15.5 # Passato come numero

    assert_equal 1550, product.price_cents
  end
end
