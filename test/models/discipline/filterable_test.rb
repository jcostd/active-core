require "test_helper"

class Discipline::FilterableTest < ActiveSupport::TestCase
  test "default order is alphabetical and kept only" do
    names = Discipline.apply_filters({}).map(&:name)
    assert_equal names.sort, names
    assert_not_includes names, "Pilates"
  end

  test "search by name" do
    assert_equal [ disciplines(:sala_pesi) ], Discipline.apply_filters(query: "pesi").to_a
  end

  test "sort descending" do
    assert_equal disciplines(:yoga), Discipline.apply_filters(sort: "name_desc").first
  end
end
