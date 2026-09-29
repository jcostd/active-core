require "test_helper"

class SportYearTest < ActiveSupport::TestCase
  test "correctly identifies sport year start in September" do
    # 15 Settembre 2025 -> Anno Sportivo 2025/2026
    date = Date.new(2025, 9, 15)
    sy = SportYear.new(date)

    assert_equal 2025, sy.year
    assert_equal Date.new(2025, 9, 1), sy.start_date
    assert_equal Date.new(2026, 8, 31), sy.end_date
  end

  test "correctly identifies sport year in January (second half)" do
    # 15 Gennaio 2026 -> Fa parte dell'Anno Sportivo iniziato nel 2025
    date = Date.new(2026, 1, 15)
    sy = SportYear.new(date)

    assert_equal 2025, sy.year # L'anno di inizio è sempre 2025
    assert_equal Date.new(2025, 9, 1), sy.start_date
    assert_equal Date.new(2026, 8, 31), sy.end_date
  end
end
