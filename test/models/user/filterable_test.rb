require "test_helper"

class User::FilterableTest < ActiveSupport::TestCase
  test "filters by role" do
    assert_equal [ users(:admin) ], User.apply_filters(role: "admin").to_a
    assert_equal [ users(:kiosk) ], User.apply_filters(role: "kiosk").to_a
    assert_equal [ users(:staff), users(:staff_two) ].sort_by(&:id), User.apply_filters(role: "staff").sort_by(&:id)
  end

  test "search by name or username" do
    assert_equal [ users(:staff_two) ], User.apply_filters(query: "Collega").to_a
    assert_equal [ users(:staff_two) ], User.apply_filters(query: "staff2").to_a
  end

  test "excludes discarded users" do
    users(:staff_two).discard!
    assert_not_includes User.apply_filters({}), users(:staff_two)
  end

  test "sort by name, unknown keys fall back to the last updated" do
    assert_equal User.kept.sort_by { [ it.last_name, it.first_name ] }, User.apply_filters(sort: "name_asc").to_a
    travel 1.second
    users(:staff_two).touch
    assert_equal users(:staff_two), User.apply_filters(sort: "username_asc").first
  end
end
