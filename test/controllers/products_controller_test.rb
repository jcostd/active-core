require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:admin)) }

  test "index, show and new" do
    get products_path
    assert_response :success
    assert_no_match "Pilates Vecchio Listino", response.body

    get product_path(products(:yoga_monthly))
    assert_response :success

    get new_product_path(discipline_id: disciplines(:yoga).id)
    assert_response :success
  end

  test "create with italian price and disciplines" do
    assert_difference -> { Product.count } do
      post products_path, params: { product: { name: "  pilates   mensile ", price: "55,50", duration_days: 30,
                                               accounting_category: "institutional", discipline_ids: [ disciplines(:yoga).id ] } }
    end
    product = Product.last
    assert_equal [ "Pilates Mensile", 5550, [ disciplines(:yoga) ] ], [ product.name, product.price_cents, product.disciplines.to_a ]
  end

  test "create carnet with entry limit" do
    post products_path, params: { product: { name: "Carnet 10", price: "80", duration_days: 90, accounting_category: "institutional", entry_limit: 10 } }
    assert_equal 10, Product.last.entry_limit
  end

  test "invalid product re-renders" do
    assert_no_difference -> { Product.count } do
      post products_path, params: { product: { name: "", price: "-1", duration_days: 0 } }
    end
    assert_response :unprocessable_entity
  end

  test "update and archive" do
    patch product_path(products(:yoga_monthly)), params: { product: { price: "50" } }
    assert_equal 5000, products(:yoga_monthly).reload.price_cents

    delete product_path(products(:yoga_monthly))
    assert products(:yoga_monthly).reload.discarded?
  end

  test "price change does not touch past sales" do
    member = members(:alice)
    grant_membership_to(member)
    sale = sell!(member:, product: products(:yoga_monthly))

    patch product_path(products(:yoga_monthly)), params: { product: { price: "99", name: "Yoga Nuovo" } }

    assert_equal 4500, sale.reload.amount_cents
    assert_equal "Yoga Mensile", sale.product_name_snapshot
    assert_equal 4500, sale.subscription.agreed_price_cents
  end
end
