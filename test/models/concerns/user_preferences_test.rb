require "test_helper"

class UserPreferencesTest < ActiveSupport::TestCase
  def setup
    @user = User.new(
      username: "pref_tester",
      password: "password",
      first_name: "Test",
      last_name: "User",
      email_address: "test@example.com"
    )
  end

  test "initializes with empty preferences hash" do
    assert_not_nil @user.preferences
    assert_equal({}, @user.preferences)
  end

  test "can write and read theme via accessor" do
    @user.theme = "dim"
    assert_equal "dim", @user.theme
    assert_equal "dim", @user.preferences["theme"]
  end

  test "validates allowed themes" do
    @user.theme = "business"
    assert @user.valid?

    @user.theme = "windows_95_ugly_theme"
    assert_not @user.valid?
    assert_includes @user.errors[:theme], "is not included in the list"

    @user.theme = nil
    assert @user.valid?
  end

  test "returns correct theme fallback" do
    # Il getter "theme" restituisce "corporate" come default se nil/blank
    @user.theme = nil
    assert_equal "corporate", @user.theme

    @user.theme = ""
    assert_equal "corporate", @user.theme

    @user.theme = "dim"
    assert_equal "dim", @user.theme
  end

  test "validates available locales" do
    @user.locale = I18n.default_locale.to_s
    assert @user.valid?

    @user.locale = "klingon"
    assert_not @user.valid?
    assert_includes @user.errors[:locale], "is not included in the list"
  end

  test "returns correct locale fallback" do
    default = I18n.default_locale.to_s

    # Il getter "locale" fa da fallback automatico
    @user.locale = nil
    assert_equal default, @user.locale

    @user.locale = "it" # Assumendo che :it sia tra gli available_locales
    assert_equal "it", @user.locale
  end

  test "persists preferences to database" do
    # Usiamo un tema valido
    @user.theme = "business"
    @user.save!

    loaded_user = User.find(@user.id)
    assert_equal "business", loaded_user.preferences["theme"]
    assert_equal "business", loaded_user.theme
  end
end
