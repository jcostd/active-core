require "test_helper"

class LanguagePreferenceTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:staff)) }

  test "valid locale is stored" do
    patch preferences_language_path(language: :it)
    assert_equal "it", users(:staff).reload.locale
  end

  test "unknown locale is rejected" do
    patch preferences_language_path(language: :xx)
    assert_equal I18n.default_locale.to_s, users(:staff).reload.locale
  end
end
