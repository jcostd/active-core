require "test_helper"

class DurationTest < ActiveSupport::TestCase
  setup do
    @course = products(:yoga_monthly)
    @membership = products(:annual_membership)
  end

  test "institutional monthly SNAPS to beginning of month and CAPS at Sport Year" do
    preference_date = Date.new(2025, 8, 15)
    expected_start = Date.new(2025, 8, 1)
    expected_end = Date.new(2025, 8, 31)

    result = Duration.for(@course, preference_date)
    assert_equal expected_start, result.start_date
    assert_equal expected_end, result.end_date
  end

  test "institutional quarterly SNAPS and CROSSES Sport Year boundary" do
    @course.update!(duration_days: 90)

    preference_date = Date.new(2025, 7, 15)
    expected_start = Date.new(2025, 7, 1)
    expected_end = Date.new(2025, 9, 30)

    result = Duration.for(@course, preference_date)
    assert_equal expected_start, result.start_date
    assert_equal expected_end, result.end_date
  end

  test "institutional annual uses ROLLING logic and IGNORES Sport Year" do
    @course.update!(duration_days: 365)

    preference_date = Date.new(2025, 5, 14)
    expected_start = Date.new(2025, 5, 14)
    expected_end = Date.new(2026, 5, 13)

    result = Duration.for(@course, preference_date)
    assert_equal expected_start, result.start_date
    assert_equal expected_end, result.end_date
  end

  test "institutional custom duration uses PURE DAYS logic with Cap" do
    @course.update!(duration_days: 45)

    preference_date = Date.new(2025, 1, 10)
    expected_start = Date.new(2025, 1, 10)
    expected_end = Date.new(2025, 2, 23)

    result = Duration.for(@course, preference_date)
    assert_equal expected_start, result.start_date
    assert_equal expected_end, result.end_date
  end

  test "associative membership ALWAYS CAPS at Sport Year End" do
    preference_date = Date.new(2025, 5, 15)
    expected_start = Date.new(2025, 5, 15)
    expected_end = Date.new(2025, 8, 31)

    result = Duration.for(@membership, preference_date)
    assert_equal expected_start, result.start_date
    assert_equal expected_end, result.end_date
  end

  test "semester snaps to the month and caps at sport year" do
    @course.update!(duration_days: 180)

    assert_equal [ Date.new(2025, 10, 1), Date.new(2026, 3, 31) ], period(Date.new(2025, 10, 20))
    assert_equal [ Date.new(2026, 5, 1), Date.new(2026, 8, 31) ], period(Date.new(2026, 5, 3))
  end

  test "monthly in august stops at the sport year end, in september starts a new one" do
    assert_equal [ Date.new(2026, 8, 1), Date.new(2026, 8, 31) ], period(Date.new(2026, 8, 31))
    assert_equal [ Date.new(2026, 9, 1), Date.new(2026, 9, 30) ], period(Date.new(2026, 9, 1))
  end

  test "quarterly handles february of a leap year" do
    @course.update!(duration_days: 90)

    assert_equal [ Date.new(2027, 12, 1), Date.new(2028, 2, 29) ], period(Date.new(2027, 12, 31))
  end

  test "366 days is a rolling year too" do
    @course.update!(duration_days: 366)

    assert_equal [ Date.new(2028, 2, 29), Date.new(2029, 2, 27) ], period(Date.new(2028, 2, 29))
  end

  test "custom duration is capped at the sport year end" do
    @course.update!(duration_days: 45)

    assert_equal [ Date.new(2026, 8, 1), Date.new(2026, 8, 31) ], period(Date.new(2026, 8, 1))
  end

  test "custom duration of one day lasts that day" do
    @course.update!(duration_days: 1)

    assert_equal [ Date.new(2026, 3, 10), Date.new(2026, 3, 10) ], period(Date.new(2026, 3, 10))
  end

  test "accepts times as preference" do
    assert_equal [ Date.new(2026, 3, 1), Date.new(2026, 3, 31) ], period(Time.zone.local(2026, 3, 15, 23, 30))
  end

  test "defines no global constants" do
    assert_not Object.const_defined?(:CALENDAR_DURATIONS)
  end

  private
    def period(date) = Duration.for(@course, date).deconstruct
end
