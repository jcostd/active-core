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

  test "category and duration are locked once the product is sold" do
    grant_membership_to(members(:alice))
    sell!(member: members(:alice), product: products(:yoga_monthly))

    patch product_path(products(:yoga_monthly)), params: { product: { accounting_category: "associative", duration_days: 365 } }

    assert_response :unprocessable_entity
    product = products(:yoga_monthly).reload
    assert product.institutional?
    assert_equal 30, product.duration_days
    assert_match "Categoria contabile non può essere cambiata", response.body
    assert_match "Durata (giorni) non può essere cambiata", response.body
  end

  test "edit form disables locked terms and explains why" do
    grant_membership_to(members(:alice))
    sell!(member: members(:alice), product: products(:yoga_monthly))

    get edit_product_path(products(:yoga_monthly))
    assert_select "select[name='product[accounting_category]'][disabled]"
    assert_select "input[name='product[duration_days]'][disabled]"
    assert_match "Categoria e durata sono bloccate", response.body
  end

  test "unsold product keeps every field editable, with italian categories" do
    get edit_product_path(products(:yoga_monthly))
    assert_select "select[name='product[accounting_category]']:not([disabled])" do
      assert_select "option", text: "Quota Associativa"
      assert_select "option", text: "Quota Istituzionale (corsi)"
    end
    assert_no_match "Categoria e durata sono bloccate", response.body

    patch product_path(products(:yoga_monthly)), params: { product: { duration_days: 90 } }
    assert_equal 90, products(:yoga_monthly).reload.duration_days
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
