require "test_helper"

class IconsHelperTest < ActionView::TestCase
  test "icon renders existing svg with defaults" do
    result = icon("chat_bubble")

    assert_match /<svg/, result
    assert_match /size-5/, result # Verifica la classe di default
  end

  test "icon accepts custom classes" do
    # Passiamo le classi per gestire dimensioni e stile, senza usare 'size: X'
    result = icon("chat_bubble", classes: "size-12 text-primary mb-2")

    assert_match /<svg/, result
    assert_match /size-12 text-primary mb-2/, result
  end

  test "icon adds custom attributes (data attributes, aria, etc)" do
    result = icon("chat_bubble", "data-controller": "tooltip", "aria-hidden": "true")

    assert_match /data-controller="tooltip"/, result
    assert_match /aria-hidden="true"/, result
  end

  test "icon renders placeholder when file is missing" do
    name = "non_existent_icon_123"
    result = icon(name)

    assert_match /<span/, result
    assert_no_match /<svg/, result
    assert_match /size-5/, result # Deve contenere la classe di default
    assert_match />#{name.first.upcase}</, result
  end

  test "icon placeholder respects custom class" do
    result = icon("non_existent_icon_123", classes: "size-16 bg-red-500")

    assert_match /<span/, result
    assert_match /size-16 bg-red-500/, result
  end

  test "icons are cached in process, not in Rails.cache" do
    IconsHelper::SVG_CACHE.clear
    reads = []
    ActiveSupport::Notifications.subscribed(->(*args) { reads << args.first }, /\Acache_/) { icon("chat_bubble") }

    assert_empty reads, "Rails.cache non va usato per le icone"
    assert IconsHelper::SVG_CACHE.key?("chat_bubble")
    assert_equal icon("chat_bubble"), icon("chat_bubble")
  end

  test "extra class is merged, never duplicated" do
    html = icon("search", classes: "size-4", class: "opacity-70")
    assert_equal 1, html.scan("class=").size
    assert_match 'class="size-4 opacity-70"', html
  end

  test "attribute values are escaped" do
    html = icon("search", title: %q{"><script>alert(1)</script>})
    assert_no_match "<script>", html
    assert_match "&quot;&gt;&lt;script&gt;", html
  end

  test "names cannot escape the icons folder" do
    assert_match "<span", icon("../../../config/master")
  end

  test "missing icons are remembered as missing" do
    IconsHelper::SVG_CACHE.clear
    icon("non_esiste")
    assert_equal false, IconsHelper::SVG_CACHE["non_esiste"]
  end
end
