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

  test "caching mechanism works" do
    first_call = icon("chat_bubble")
    second_call = icon("chat_bubble")

    assert_equal first_call, second_call
  end
end
