require "test_helper"

class UiHelperTest < ActionView::TestCase
  include IconsHelper

  test "avatar shows initials with a stable color" do
    html = ui_avatar(members(:alice))
    assert_match "AA", html
    assert_match "hsl(", html
    assert_equal html, ui_avatar(members(:alice))
  end

  test "row buttons" do
    assert_match 'data-turbo-frame="modal"', ui_row_edit_button("/x")
    delete = ui_row_delete_button("/x", confirm: "Sicuro?")
    assert_match 'data-turbo-method="delete"', delete
    assert_match "Sicuro?", delete
  end

  test "requirement and status badges" do
    assert_match "Richiede Quota", ui_requirement_badge(true, text: "Quota", icon_name: "badge")
    assert_match "No Quota", ui_requirement_badge(false, text: "Quota", icon_name: "badge")
    assert_match "Valido", ui_status_badge(true, valid_text: "Valido", invalid_text: "Scaduto")
    assert_match "Attenzione: Scaduto", ui_status_badge(false, valid_text: "Valido", invalid_text: "Scaduto")
  end

  test "badge escapes content" do
    assert_no_match "<script>", ui_badge("<script>")
  end
end
