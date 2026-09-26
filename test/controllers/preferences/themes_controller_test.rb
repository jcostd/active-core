require "test_helper"

class Preferences::ThemesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:staff)) }

  test "valid theme is stored and applied" do
    patch preferences_theme_path(theme: "dark")
    assert_equal "dark", users(:staff).reload.theme

    get root_path
    assert_select "body[data-theme-sync-theme-value=dark]"
  end

  test "unknown theme is ignored" do
    patch preferences_theme_path(theme: "fucsia")
    assert_equal "corporate", users(:staff).reload.theme
  end
end
