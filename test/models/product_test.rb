require "test_helper"

class ProductTest < ActiveSupport::TestCase
  setup do
    @product = products(:yoga_monthly)
  end


  test "name normalization squishes spaces" do
    product = Product.new(
      name: "  abbonamento   open  ",
      price_cents: 1000,
      duration_days: 30
    )
    product.validate
    assert_equal "Abbonamento Open", product.name
  end

  test "price validation" do
    @product.price_cents = -500
    assert_not @product.valid?
    assert_includes @product.errors[:price_cents], "deve essere maggiore o uguale a 0"

    @product.price_cents = 0 # Gratis è ok
    assert @product.valid?
  end

  test "duration validation" do
    @product.duration_days = 0
    assert_not @product.valid?

    @product.duration_days = 1.5 # Deve essere intero
    assert_not @product.valid?
  end


  test "monetizable concern integration" do
    product = Product.new
    product.price = "1.250,50" # Input IT
    assert_equal 125050, product.price_cents
  end

  test "soft delete logic" do
    # Unicità: Posso creare un prodotto con lo stesso nome di uno cancellato
    deleted_product = products(:pilates_legacy)
    assert deleted_product.discarded?

    new_pilates = Product.new(
      name: "Pilates Vecchio Listino", # Stesso nome del cancellato
      price_cents: 5000,
      duration_days: 30
    )
    assert new_pilates.valid?
  end


  test "a product with payments cannot be hard deleted" do
    member = members(:alice)
    grant_membership_to(member)
    sell!(member:, product: @product)

    assert_not @product.destroy
    assert Product.exists?(@product.id)
    assert @product.errors[:base].any?
  end
end
