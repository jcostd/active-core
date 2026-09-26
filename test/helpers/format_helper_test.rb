require "test_helper"

class FormatHelperTest < ActionView::TestCase
  # ==========================================
  # TEST AGNOSTICI (Funzionano in qualsiasi lingua)
  # ==========================================

  test "display_value returns value directly if present" do
    assert_equal "Mario", display_value("Mario")
    assert_equal 123, display_value(123)
  end

  test "display_value returns styled placeholder if nil or empty" do
    # Caso nil
    result = display_value(nil)
    assert_match /span/, result
    assert_match /text-base-content\/40/, result
    assert_match /—/, result

    # Caso stringa vuota
    result_empty = display_value("")
    assert_dom_equal result, result_empty
  end

  test "display_value uses custom placeholder" do
    result = display_value(nil, placeholder: "N/A")
    assert_match /N\/A/, result
  end

  test "display_value executes block only if value is present" do
    # Caso con valore
    result = display_value("http://example.com") do |val|
      link_to("Link", val)
    end
    assert_match /href="http:\/\/example.com"/, result
    assert_match />Link<\/a>/, result

    # Caso nil
    result_nil = display_value(nil) { |val| "Non dovrei vedermi" }
    assert_no_match /Non dovrei vedermi/, result_nil
    assert_match /—/, result_nil
  end

  test "format_email generates mailto link" do
    email = "test@example.com"
    result = format_email(email)
    assert_match /href="mailto:test@example.com"/, result
    assert_match />test@example.com<\/a>/, result
  end

  # ==========================================
  # TEST IN ITALIANO (Forziamo il locale :it)
  # ==========================================

  test "format_date returns formatted date" do
    I18n.with_locale(:it) do
      date = Date.new(2023, 12, 25)
      # I18n.l userà il formato italiano automaticamente qui dentro
      expected = I18n.l(date)
      assert_equal expected, format_date(date)
    end
  end

  test "format_date handles nil" do
    assert_match /span/, format_date(nil)
  end

  test "format_time_ago generates tooltip" do
    I18n.with_locale(:it) do
      time = 2.hours.ago
      result = format_time_ago(time)

      # Verifichiamo il title (es. "26 Dicembre...")
      assert_match /title="#{I18n.l(time, format: :long)}"/, result
      # Verifichiamo "circa 2 ore" (italiano)
      assert_match /ore/, result
    end
  end

  test "format_money handles raw numbers" do
    I18n.with_locale(:it) do
      # In Italia: 10,50 €
      result = format_money(10.50)
      assert_match /10,50/, result # Virgola
      assert_match /€/, result     # Simbolo
    end
  end
end
