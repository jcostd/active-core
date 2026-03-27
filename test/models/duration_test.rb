require "test_helper"

class DurationTest < ActiveSupport::TestCase
  setup do
    @course = products(:yoga_monthly)
    @membership = products(:annual_membership)
  end

  test "institutional monthly SNAPS to beginning of month and CAPS at Sport Year" do
    preference_date = Date.new(2025, 8, 15)
    result = Duration.new(@course, preference_date).calculate

    assert_equal Date.new(2025, 8, 1), result[:start_date]
    assert_equal Date.new(2025, 8, 31), result[:end_date]
  end

  test "institutional quarterly SNAPS and CROSSES Sport Year boundary" do
    @course.update!(duration_days: 90)
    preference_date = Date.new(2025, 7, 15)

    result = Duration.new(@course, preference_date).calculate

    assert_equal Date.new(2025, 7, 1), result[:start_date]
    assert_equal Date.new(2025, 9, 30), result[:end_date]
  end

  test "institutional annual uses ROLLING logic and IGNORES Sport Year" do
    @course.update!(duration_days: 365)
    preference_date = Date.new(2025, 5, 14)

    result = Duration.new(@course, preference_date).calculate

    assert_equal Date.new(2025, 5, 14), result[:start_date]
    assert_equal Date.new(2026, 5, 13), result[:end_date]
  end

  test "institutional custom duration uses PURE DAYS logic with Cap" do
    @course.update!(duration_days: 45)
    preference_date = Date.new(2025, 1, 10)

    result = Duration.new(@course, preference_date).calculate

    assert_equal Date.new(2025, 1, 10), result[:start_date]
    assert_equal Date.new(2025, 2, 23), result[:end_date]
  end

  test "associative membership ALWAYS CAPS at Sport Year End" do
    preference_date = Date.new(2025, 5, 15)
    result = Duration.new(@membership, preference_date).calculate

    assert_equal preference_date, result[:start_date]
    assert_equal Date.new(2025, 8, 31), result[:end_date]
  end
end
