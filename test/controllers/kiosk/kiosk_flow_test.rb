require "test_helper"

class KioskFlowTest < ActionDispatch::IntegrationTest
  setup do
    @alice = members(:alice)
    @yoga = disciplines(:yoga)
    grant_membership_to(@alice)
    @course = link!(products(:yoga_monthly), @yoga)
    sign_in_as(users(:staff))
  end

  test "kiosk home lists kept disciplines" do
    get kiosk_root_path
    assert_response :success
    assert_match "Yoga", response.body
    assert_no_match ">Pilates<", response.body
  end

  test "discipline page lists subscribed members to check in" do
    sell!(member: @alice, product: @course)

    get kiosk_discipline_path(@yoga)
    assert_response :success
    assert_select "##{ActionView::RecordIdentifier.dom_id(@alice, :pending)}"
  end

  test "checked in member moves to the room list" do
    sell!(member: @alice, product: @course)
    post kiosk_discipline_access_logs_path(@yoga, member_id: @alice.id)

    get kiosk_discipline_path(@yoga)
    assert_select "##{ActionView::RecordIdentifier.dom_id(@alice, :pending)}", count: 0
    assert_select "##{ActionView::RecordIdentifier.dom_id(AccessLog.last)}"
  end

  test "flash reflects the access outcome" do
    sell!(member: @alice, product: @course, user: users(:admin), start_date: Date.current - 20, end_date: Date.current + 30)
    post kiosk_discipline_access_logs_path(@yoga, member_id: @alice.id)
    assert_equal "Check-in registrato per Alice", flash[:success]

    post kiosk_discipline_access_logs_path(@yoga, member_id: members(:bob).id)
    assert_equal "Check-in registrato per Bob, da regolarizzare: Quota Associativa scaduta o mancante. " \
                 "Nessun abbonamento attivo per 'Yoga'.", flash[:error]
  end

  test "missing course with a valid membership names only the course" do
    post kiosk_discipline_access_logs_path(@yoga, member_id: @alice.id)

    assert_equal "Check-in registrato per Alice, da regolarizzare: Nessun abbonamento attivo per 'Yoga'.", flash[:error]
    assert AccessLog.last.error?
  end

  test "expiring subscription warning does not mention the certificate" do
    sell!(member: @alice, product: @course, user: users(:admin), start_date: Date.current - 20, end_date: Date.current + 3)
    post kiosk_discipline_access_logs_path(@yoga, member_id: @alice.id)

    assert_equal "Check-in registrato per Alice: Abbonamento in scadenza tra 3 giorni.", flash[:info]
    assert_nil flash[:success]
  end

  test "expired certificate warning names the certificate" do
    bob = members(:bob)
    grant_membership_to(bob)
    sell!(member: bob, product: @course, user: users(:admin), start_date: Date.current - 20, end_date: Date.current + 30)
    post kiosk_discipline_access_logs_path(@yoga, member_id: bob.id)

    assert_equal "Check-in registrato per Bob: Certificato Medico scaduto o mancante.", flash[:info]
  end

  test "certificate and expiry warnings are both shown" do
    bob = members(:bob)
    grant_membership_to(bob)
    sell!(member: bob, product: @course, user: users(:admin), start_date: Date.current - 20, end_date: Date.current)
    post kiosk_discipline_access_logs_path(@yoga, member_id: bob.id)

    assert_equal "Check-in registrato per Bob: Certificato Medico scaduto o mancante. Abbonamento in scadenza oggi.", flash[:info]
  end

  test "warning check-in shows as an info toast" do
    bob = members(:bob)
    grant_membership_to(bob)
    sell!(member: bob, product: @course, user: users(:admin), start_date: Date.current - 20, end_date: Date.current + 30)
    post kiosk_discipline_access_logs_path(@yoga, member_id: bob.id)
    follow_redirect!

    assert_select ".alert.alert-info", text: /Certificato Medico scaduto/
  end

  test "double tap shows an error and records nothing" do
    post kiosk_discipline_access_logs_path(@yoga, member_id: @alice.id)

    assert_no_difference -> { AccessLog.count } do
      post kiosk_discipline_access_logs_path(@yoga, member_id: @alice.id)
    end
    assert_match "Impossibile registrare il check-in", flash[:error]
  end


  test "kiosk has no way to cancel a check-in" do
    post kiosk_discipline_access_logs_path(@yoga, member_id: @alice.id)

    get kiosk_discipline_path(@yoga)
    assert_select "form[method=post] input[name=_method][value=delete]", count: 0
    assert_raises(NameError) { kiosk_discipline_access_log_path(@yoga, AccessLog.last) }
  end

  test "kiosk search returns check-in buttons" do
    get kiosk_discipline_member_searches_path(@yoga, query: "Ali")
    assert_select "form[action='#{kiosk_discipline_access_logs_path(@yoga, member_id: @alice.id)}']"
  end

  test "kiosk search hides fiscal code and full birth date" do
    get kiosk_discipline_member_searches_path(@yoga, query: "Ali")

    assert_no_match @alice.fiscal_code, response.body
    assert_no_match I18n.l(@alice.birth_date), response.body
    assert_match "Nato/a nel #{@alice.birth_date.year}", response.body
  end

  test "kiosk search finds members only by name" do
    get kiosk_discipline_member_searches_path(@yoga, query: "Allevi")
    assert_match @alice.full_name, response.body

    [ @alice.fiscal_code.first(6), "alice@example", "3331234567" ].each do |query|
      get kiosk_discipline_member_searches_path(@yoga, query:)
      assert_no_match @alice.full_name, response.body, "il kiosk non deve trovare soci per #{query}"
    end
  end

  test "kiosk search box does not suggest searching by fiscal code" do
    get kiosk_discipline_path(@yoga)
    assert_select "input[placeholder='Cerca nome o cognome...']"
  end

  test "cards show the real access outcome" do
    sell!(member: @alice, product: @course, user: users(:admin), start_date: Date.current - 5, end_date: Date.current + 30)
    Subscription.create!(member: members(:bob), product: @course, start_date: Date.current - 5, end_date: Date.current + 30) # senza quota

    get kiosk_discipline_path(@yoga)

    alice_card = "##{ActionView::RecordIdentifier.dom_id(@alice, :pending)}"
    bob_card = "##{ActionView::RecordIdentifier.dom_id(members(:bob), :pending)}"
    assert_select "#{alice_card} .btn-primary"
    assert_select "#{alice_card} .btn-error", count: 0
    assert_select "#{bob_card} .btn-error"
  end

  test "cards explain what is missing" do
    Subscription.create!(member: members(:bob), product: @course, start_date: Date.current - 5, end_date: Date.current + 30)

    get kiosk_discipline_path(@yoga)
    assert_select "##{ActionView::RecordIdentifier.dom_id(members(:bob), :pending)}", text: /Quota mancante/
  end
end
