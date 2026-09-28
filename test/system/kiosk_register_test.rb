require "application_system_test_case"

# il registro del mese sull'iPad: tocchi, ricerca e correzioni nel browser vero
class KioskRegisterTest < ApplicationSystemTestCase
  setup do
    @yoga = disciplines(:yoga)
    course = link!(products(:yoga_monthly), @yoga)
    grant_membership_to(members(:alice))
    sell!(member: members(:alice), product: course)
    sign_in "kiosk"
    click_on "Yoga"
  end

  test "tapping a proposed member moves the card into the register" do
    within("#pending_members") { click_on "Smarca Alice Allevi" }

    within("#attendances") { assert_text "Alice Allevi" }
    within("#pending_members") { assert_no_text "Alice Allevi" }
    assert_text "Alice è nel registro"
  end

  test "a newcomer is found by name and marked" do
    fill_in "members_search", with: "Bian"
    click_on "Bob Bianchi"

    within("#attendances") { assert_text "Bob Bianchi" }
    assert_text "Non iscritto"
  end

  test "an incoming refresh does not wipe what the instructor is searching" do
    fill_in "members_search", with: "Bian"
    within("#kiosk_search") { assert_text "Bob Bianchi" }

    Attendance.create!(member: members(:alice), discipline: @yoga, marked_by: users(:staff)) # smarcata da un altro iPad
    page.execute_script(%(Turbo.renderStreamMessage('<turbo-stream action="refresh"></turbo-stream>')))

    within("#attendances") { assert_text "Alice Allevi" }
    assert_field "members_search", with: "Bian"
    within("#kiosk_search") { assert_text "Bob Bianchi" }
  end

  test "marking from the search clears it" do
    fill_in "members_search", with: "Bian"
    click_on "Bob Bianchi"

    within("#attendances") { assert_text "Bob Bianchi" }
    assert_field "members_search", with: ""
    within("#kiosk_search") { assert_no_text "Bob Bianchi" }
  end

  test "removing a mark asks for confirmation" do
    within("#pending_members") { click_on "Smarca Alice Allevi" }
    within("#attendances") { assert_text "Alice Allevi" }

    dismiss_confirm { click_on "Togli Alice Allevi dal registro" }
    within("#attendances") { assert_text "Alice Allevi" }

    accept_confirm { click_on "Togli Alice Allevi dal registro" }
    within("#pending_members") { assert_text "Alice Allevi" }
    assert_equal 0, Attendance.count
  end
end
