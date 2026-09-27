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
    assert_selector "[data-controller=filter-badge] .badge", text: "Quota valida"

    find("[data-action='filter-badge#remove']").click
    assert_no_selector "[data-controller=filter-badge] .badge"

    click_on "Filtri"
    assert_selector "dialog[open]", text: "Stato Tesseramento"
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

  private
    # le pagine in modale si aprono dai loro link, come fa l'utente
    def open_modal(path, link)
      visit path
      click_on link
      assert_selector "dialog[open]"
    end
end
