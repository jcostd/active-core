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

  test "unparsable input is a validation error, not a crash" do
    %w[abc - 1.2.3 € 12,5,0].each do |input|
      product = Product.new(name: "X", duration_days: 30)
      assert_nothing_raised { product.price = input }
      assert_nil product.price_cents, input
      assert_not product.valid?
      assert_includes product.errors[:price], "non è un importo valido", input
    end
  end

  test "a later valid value clears the parse error" do
    product = products(:yoga_monthly)
    product.price = "abc"
    product.price = "10"
    assert product.valid?
  end

  test "unparsable amount never falls back to the list price" do
    member = members(:alice)
    grant_membership_to(member)
    sale = Sale.new(member:, product: products(:yoga_monthly), user: users(:staff), sold_on: Date.current, amount: "dieci",
                    subscription_attributes: { member:, product: products(:yoga_monthly) })

    assert_not sale.save
    assert_includes sale.errors.full_messages, "Importo non è un importo valido"
  end
end
