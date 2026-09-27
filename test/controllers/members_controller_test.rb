require "test_helper"

class MembersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = members(:alice)
    sign_in_as(users(:staff))
  end

  VALID = { first_name: "mario", last_name: "rossi", fiscal_code: "rssmra80a01h501u", birth_date: "1980-01-01",
            phone: "3331234567", email_address: "MARIO@EXAMPLE.COM", medical_certificate_expiry: "2027-01-01" }

  test "index lists kept members" do
    get members_path
    assert_response :success
    assert_match "Alice Allevi", response.body
    assert_no_match "Cancellato", response.body
  end

  test "index search survives fts operator words" do
    get members_path(query: "OR NOT *")
    assert_response :success
  end

  test "index filters by membership" do
    grant_membership_to(@alice)
    get members_path(membership_status: "active")
    assert_match "Alice Allevi", response.body
    assert_no_match "Bob Bianchi", response.body
  end

  test "show renders the member card" do
    get member_path(@alice)
    assert_response :success
    assert_match @alice.fiscal_code, response.body
  end

  test "create normalizes and saves" do
    assert_difference -> { Member.count } do
      post members_path, params: { member: VALID }
    end
    member = Member.last
    assert_redirected_to member_path(member)
    assert_equal [ "Mario", "Rossi", "RSSMRA80A01H501U", "mario@example.com" ],
                 [ member.first_name, member.last_name, member.fiscal_code, member.email_address ]
  end

  test "create keeps apostrophes and mixed case in names" do
    post members_path, params: { member: VALID.merge(first_name: "ANNA-MARIA", last_name: "dell'orto", address: "via xx settembre 4/b") }

    member = Member.last
    assert_equal [ "Anna-Maria", "Dell'Orto", "Via XX Settembre 4/B" ], [ member.first_name, member.last_name, member.address ]
  end

  test "create with errors re-renders in italian" do
    assert_no_difference -> { Member.count } do
      post members_path, params: { member: VALID.merge(fiscal_code: "corto", first_name: "") }
    end
    assert_response :unprocessable_entity
    assert_match "Codice fiscale non è valido: controlla", response.body
    assert_match "Nome non può essere lasciato in bianco", response.body
  end

  test "duplicate fiscal code is rejected" do
    post members_path, params: { member: VALID.merge(fiscal_code: @alice.fiscal_code) }
    assert_response :unprocessable_entity
    assert_match "Codice fiscale è già presente", response.body
  end

  test "update medical certificate" do
    patch member_path(@alice), params: { member: { medical_certificate_expiry: "2030-05-05" } }
    assert_redirected_to member_path(@alice)
    assert_equal Date.new(2030, 5, 5), @alice.reload.medical_certificate_expiry
  end

  test "update with errors re-renders" do
    patch member_path(@alice), params: { member: { last_name: "" } }
    assert_response :unprocessable_entity
  end

  test "admin archives a member" do
    sign_in_as(users(:admin))
    delete member_path(@alice)
    assert_redirected_to members_path
    assert @alice.reload.discarded?
  end

  test "member subscriptions and accesses pages" do
    grant_membership_to(@alice)
    get member_subscriptions_path(@alice)
    assert_response :success
    assert_match "Quota Associativa 2025", response.body

    get member_access_logs_path(@alice)
    assert_response :success
  end

  test "member sales history shows total for admin" do
    grant_membership_to(@alice)
    sign_in_as(users(:admin))

    get member_sales_path(@alice)
    assert_response :success
    assert_equal @alice.sales.kept.sum(:amount_cents), controller.instance_variable_get(:@total_amount_cents)
    assert_match format("%.2f", @alice.sales.kept.sum(:amount_cents) / 100.0).tr(".", ","), response.body
  end

  test "overpaid legacy subscription shows as settled, not negative" do
    grant_membership_to(@alice)
    sub = sell!(member: @alice, product: products(:yoga_monthly)).subscription
    sub.update_columns(agreed_price_cents: 1000)

    get member_subscriptions_path(@alice)
    assert_no_match(/Resta: -/, response.body)
    assert_match "Saldato", response.body
  end

  test "create a member with pending fiscal code" do
    assert_difference -> { Member.missing_fiscal_code.count } do
      post members_path, params: { member: VALID.merge(fiscal_code: "", fiscal_code_pending: "1") }
    end
    get members_path
    assert_match "CF da completare", response.body
  end

  test "create without fiscal code and without the box is refused" do
    post members_path, params: { member: VALID.merge(fiscal_code: "") }
    assert_response :unprocessable_entity
    assert_match "CF da completare", response.body
  end
end
