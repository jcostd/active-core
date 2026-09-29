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

  test "italian and english grouping both work" do
    {
      "1.200,50" => 120050, "1,200.50" => 120050, "1.234.567,89" => 123456789,
      "1.200" => 120000, "12.50" => 1250, "12,5" => 1250, "0,05" => 5, "-3" => -300, "45 €" => 4500
    }.each do |input, cents|
      assert_equal cents, Monetizable.cents(input), input
    end
  end

  test "numbers are converted without float errors" do
    assert_equal 1999, Monetizable.cents(19.99)
    assert_equal 1005, Monetizable.cents(10.05)
    assert_equal 1234, Monetizable.cents(BigDecimal("12.34"))
  end

  test "malformed text is not an amount" do
    [ "12.345,6,7", "1,2,3", "12.5.0", "123456,789", "€", "-", "dieci" ].each do |input|
      assert_nil Monetizable.cents(input), input
    end
  end

  test "absurd amounts are not amounts" do
    assert_equal 999_999_999, Monetizable.cents("9.999.999,99")
    [ "10.000.000", "99999999999999999999", 1e20, "-99999999999" ].each do |input|
      assert_nil Monetizable.cents(input), input
    end
  end

  test "an absurd price is a validation error, not a crash" do
    product = products(:yoga_monthly)
    product.price = "99999999999999999999"

    assert_not product.save
    assert_includes product.errors.full_messages, "Prezzo non è un importo valido"
  end

  test "two decimals after a single separator are always cents" do
    assert_equal 120, Monetizable.cents("1.20")
    assert_equal 120, Monetizable.cents("1,20")
  end

  test "reader returns euros" do
    assert_equal 12.5, Product.new(price_cents: 1250).price
    assert_nil Product.new(price_cents: nil).price
  end
end
