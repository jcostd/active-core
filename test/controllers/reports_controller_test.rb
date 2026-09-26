require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = members(:alice)
    grant_membership_to(@member)
    sign_in_as(users(:admin))
  end

  test "monthly report splits the day like the daily detail" do
    day = Date.current.beginning_of_month + 9
    travel_to day.in_time_zone.change(hour: 14, min: 30) do
      sell!(member: @member, product: products(:yoga_monthly), amount: 12, agreed_price: 100)
    end

    get reports_path(month: day.strftime("%Y-%m"))
    assert_response :success
    report = controller.instance_variable_get(:@daily_reports).find { it.date == day }

    assert_equal 0, report.morning_cents
    assert_equal 1200, report.afternoon_cents
    assert_equal DailyCash.for(day).afternoon_cents, report.afternoon_cents
  end

  test "monthly total sums cash only" do
    Sale.delete_all
    sell!(member: @member, product: products(:yoga_monthly), amount: 10, agreed_price: 100)
    sell!(member: @member, product: products(:yoga_monthly), amount: 5, agreed_price: 100, payment_method: :credit_card,
          start_date: Date.current.next_month.beginning_of_month)

    get reports_path
    cash = Sale.kept.where(payment_method: :cash, sold_on: Date.current.all_month).sum(:amount_cents) / 100.0
    assert_in_delta cash, controller.instance_variable_get(:@monthly_total)
    assert_operator cash, :>=, 10.0
  end

  test "invalid month falls back to the current month" do
    %w[2026-13 abc 2026-1 ../../etc].each do |month|
      get reports_path(month:)
      assert_response :success
      assert_equal Date.current.beginning_of_month, controller.instance_variable_get(:@date).beginning_of_month
    end
  end

  test "daily detail renders" do
    sell!(member: @member, product: products(:yoga_monthly), amount: 10, agreed_price: 100)

    get report_path("daily_cash", date: Date.current.iso8601)
    assert_response :success
    assert_match "Alice", response.body
  end

  test "daily detail with invalid date falls back to today" do
    get report_path("daily_cash", date: "2026-02-31")
    assert_response :success
    assert_equal Date.current, controller.instance_variable_get(:@date)
  end

  test "unknown report type redirects" do
    get report_path("fantasia")
    assert_redirected_to reports_path
    assert_equal "Tipo di report non valido.", flash[:alert]
  end
end
