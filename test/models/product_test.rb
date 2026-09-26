require "test_helper"

class ProductTest < ActiveSupport::TestCase
  setup do
    @product = products(:yoga_monthly)
  end

  test "valid product setup" do
    assert @product.valid?
    assert @product.institutional?
    assert_equal 45.00, @product.price
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
    assert_includes @product.errors[:price_cents], "must be greater than or equal to 0"

    @product.price_cents = 0 # Gratis è ok
    assert @product.valid?
  end

  test "duration validation" do
    @product.duration_days = 0
    assert_not @product.valid?

    @product.duration_days = 1.5 # Deve essere intero
    assert_not @product.valid?
  end

  test "membership product is associative" do
    membership = products(:annual_membership)
    assert membership.associative?
    assert_not membership.institutional?
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

  test "association with disciplines" do
    # Verifichiamo che possiamo collegare una disciplina
    yoga = disciplines(:yoga)
    @product.disciplines << yoga

    assert_includes @product.disciplines, yoga
    assert_equal 1, @product.product_disciplines.count
  end

  test "cannot delete product with sales" do
    # Verifica strutturale della protezione
    reflection = Product.reflect_on_association(:sales)
    assert_equal :restrict_with_error, reflection.options[:dependent]
  end
end
