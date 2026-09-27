require "test_helper"

class NavigationHelperTest < ActionView::TestCase
  # Helper per simulare la pagina corrente nei test
  def set_current_path(path)
    controller.request.path = path
  end

  test "active_link_to adds menu-active class when on current page" do
    set_current_path("/users")

    # Caso standard
    result = active_link_to("Utenti", "/users")
    assert_match /menu-active/, result

    # Caso non attivo
    result_inactive = active_link_to("Home", "/home")
    assert_no_match /menu-active/, result_inactive
  end

  test "active_link_to supports block syntax" do
    set_current_path("/settings")

    result = active_link_to("/settings") do
      tag.span("Impostazioni")
    end

    assert_match /menu-active/, result
    assert_match /href="\/settings"/, result
    assert_match /<span>Impostazioni<\/span>/, result
  end

  test "active_link_to accepts existing classes" do
    set_current_path("/profile")

    result = active_link_to("Profilo", "/profile", class: "text-lg")

    # Deve mantenere text-lg E aggiungere menu-active
    assert_match /text-lg/, result
    assert_match /menu-active/, result
  end
end
