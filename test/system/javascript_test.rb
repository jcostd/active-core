require "application_system_test_case"

# i controller Stimulus nel browser vero
class JavascriptTest < ApplicationSystemTestCase
  setup { sign_in "admin" }

  test "the theme is on html from the first paint" do
    visit root_path
    assert_selector "html[data-theme=corporate]", visible: :all
  end

  test "typing a fiscal code fills the birth date" do
    open_modal members_path, "Nuovo"
    fill_in "member[fiscal_code]", with: "rssmra80a41h501u"

    assert_field "member[fiscal_code]", with: "RSSMRA80A41H501U"
    assert_field "member[birth_date]", with: "1980-01-01"
  end

  test "an omocode fiscal code still gives the birth date" do
    open_modal members_path, "Nuovo"
    fill_in "member[fiscal_code]", with: "RSSMRAULAQMH501U" # 80 -> UL, 41 -> QM

    assert_field "member[birth_date]", with: "1980-01-01"
  end

  test "the POS finds a member and reloads the draft for them" do
    open_modal root_path, "Nuova Vendita"
    fill_in "members_search", with: "Alic"
    click_on "Alice Allevi"

    assert_selector "input[name='sale[member_id]'][value='#{members(:alice).id}']", visible: :all
    assert_field "members_search", with: "Alice Allevi"
  end

  test "choosing a product in the POS proposes price and dates" do
    open_modal root_path, "Nuova Vendita"
    fill_in "members_search", with: "Alic"
    click_on "Alice Allevi"
    select products(:annual_membership).name, from: "sale[product_id]"

    assert_field "sale[amount]", with: /\A#{products(:annual_membership).price_cents / 100}/
    assert_selector "input[name='sale[subscription_attributes][end_date]']:not([value=''])", visible: :all
  end

  test "filter drawer and active filter chips" do
    grant_membership_to(members(:alice))
    visit members_path(membership_status: "active")
    assert_selector "#active_filters .badge", text: "Quota valida"

    find("a[aria-label='Rimuovi filtro Stato Tesseramento']").click
    assert_no_selector "#active_filters"
    assert_no_current_path(/membership_status/)

    click_on "Filtri"
    assert_selector "dialog[open]", text: "Stato Tesseramento"
  end

  test "after the idle timeout the browser signs out with the form of the page" do
    visit members_path
    page.execute_script(%(Stimulus.getControllerForElementAndIdentifier(document.body, "idle").signOut()))

    assert_current_path new_session_path
    assert_text "Sessione scaduta per inattività."
    visit members_path
    assert_current_path new_session_path
  end

  test "flash messages go away by themselves" do
    Capybara.reset_session!
    visit new_session_path
    fill_in "username", with: "admin"
    fill_in "password", with: "sbagliata"
    click_on "Entra"

    assert_selector ".alert", text: "Username o password non corretti"
    assert_no_selector ".alert", wait: 7
  end

  test "a live refresh does not wipe the POS being filled in" do
    open_modal root_path, "Nuova Vendita"
    fill_in "members_search", with: "Alic"
    click_on "Alice Allevi"
    assert_selector "input[name='sale[member_id]'][value='#{members(:alice).id}']", visible: :all

    Attendance.create!(member: members(:bob), discipline: disciplines(:yoga), marked_by: users(:kiosk))
    refresh_from_server
    assert_selector "#unenrolled_attendances", text: "Bob Bianchi", visible: :all # la pagina sotto si è aggiornata

    assert_selector "dialog[open]"
    assert_selector "input[name='sale[member_id]'][value='#{members(:alice).id}']", visible: :all
  end

  test "a live refresh does not close the filter drawer" do
    visit members_path
    click_on "Filtri"
    assert_selector "dialog[open]", text: "Stato Tesseramento"

    Member.create!(first_name: "Nuovo", last_name: "Arrivo", birth_date: 30.years.ago, fiscal_code_pending: true)
    refresh_from_server
    assert_selector "#members_list, body", text: "Nuovo Arrivo", visible: :all
    assert_selector "dialog[open]", text: "Stato Tesseramento"
  end

  test "once closed, the modal is not brought back by a refresh" do
    open_modal root_path, "Nuova Vendita"
    find("dialog[open] .modal-box button[aria-label=Chiudi]").click
    assert_no_selector "dialog[open]"

    refresh_from_server
    assert_no_selector "dialog[open]"
    assert_no_selector "turbo-frame#modal *"
  end

  test "saving in a modal closes it and updates the page below" do
    visit member_path(members(:alice))
    open_member_edit
    fill_in "member[phone]", with: "3339998888"
    within("dialog[open]") { click_on "Salva" }

    assert_no_selector "dialog[open]"
    assert_text "Socio aggiornato con successo."
    assert_text "333 999 8888"
    assert_equal "3339998888", members(:alice).reload.phone
  end

  test "validation errors keep the modal open" do
    visit member_path(members(:alice))
    open_member_edit
    fill_in "member[last_name]", with: ""
    within("dialog[open]") { click_on "Salva" }

    within("dialog[open]") { assert_text "Cognome" }
    assert_equal "Allevi", members(:alice).reload.last_name
  end

  test "the modal closes with Esc and by clicking outside, and opens again" do
    open_modal root_path, "Nuova Vendita"
    find("dialog[open]").send_keys(:escape)
    assert_no_selector "dialog[open]"

    click_on "Nuova Vendita"
    assert_selector "dialog[open]"
    find("dialog[open] form.modal-backdrop button", visible: :all).execute_script("this.click()")
    assert_no_selector "dialog[open]"
  end

  test "a sale from the POS lands on the sale page, without a modal" do
    grant_membership_to(members(:alice))
    open_modal root_path, "Nuova Vendita"
    fill_in "members_search", with: "Alic"
    within("dialog[open]") { click_on "Alice Allevi" }
    select products(:annual_membership).name, from: "sale[product_id]"
    assert_field "sale[amount]", with: /30/
    within("dialog[open]") { click_on "Conferma", match: :first }

    assert_text "Vendita registrata con successo."
    assert_current_path sale_path(Sale.order(:id).last)
    assert_no_selector "dialog[open]"
  end

  test "feedback is sent from its modal" do
    visit members_path
    click_on "Invia Feedback"
    within("dialog[open]") do
      fill_in "feedback[message]", with: "Il pulsante stampa non si vede"
      click_on "Invia"
    end

    assert_no_selector "dialog[open]"
    assert_text "Segnalazione inviata"
    assert_current_path members_path
  end

  test "saving a subscription from the modal closes it and says so" do
    subscription = sell!(member: members(:alice), product: products(:annual_membership)).subscription
    visit member_subscriptions_path(members(:alice))
    find("a[href='#{edit_subscription_path(subscription)}']").click
    assert_selector "dialog[open]"

    within("dialog[open]") do
      fill_in "subscription[end_date]", with: (subscription.end_date - 1).iso8601
      click_on "Salva"
    end

    assert_no_selector "dialog[open]"
    assert_text "Abbonamento aggiornato con successo."
    assert_equal subscription.end_date - 1, subscription.reload.end_date
  end

  # la CSP deve lasciar passare il websocket di Action Cable, o gli aggiornamenti live si fermano in silenzio
  test "live updates connect to the server" do
    visit products_path
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
  end

  private
    # come un broadcast_refresh ricevuto da Solid Cable
    def refresh_from_server
      page.execute_script(%(Turbo.renderStreamMessage('<turbo-stream action="refresh"></turbo-stream>')))
    end

    def open_member_edit
      click_on "Modifica"
      assert_selector "dialog[open]"
    end

    # le pagine in modale si aprono dai loro link, come fa l'utente
    def open_modal(path, link)
      visit path
      click_on link
      assert_selector "dialog[open]"
    end
end
