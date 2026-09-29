require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = members(:alice)
    grant_membership_to(@member)
    Sale.delete_all # via gli incassi della quota al 1° gennaio
    sign_in_as(users(:admin))
  end

  test "monthly report splits the day like the daily detail" do
    day = Date.current
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
    cash = Sale.kept.where(payment_method: :cash, sold_on: Date.current.all_month).sum(:amount_cents)
    assert_equal cash, controller.instance_variable_get(:@monthly_total_cents)
    assert_operator cash, :>=, 1000
  end

  test "a backdated sale shows on its day as registered later" do
    yesterday = Date.current - 1
    sell!(member: @member, product: products(:yoga_monthly), user: users(:admin), amount: 7, agreed_price: 100, sold_on: yesterday)

    get report_path("daily_cash", date: yesterday.iso8601)
    assert_select "h2", text: "Registrate in seguito"
    assert_match "7,00", response.body

    get reports_path(month: yesterday.strftime("%Y-%m"))
    assert_match "Registrate in seguito", response.body
    assert_equal 700, controller.instance_variable_get(:@monthly_total_cents)
  end

  test "daily detail has no late section when every sale was registered on its day" do
    sell!(member: @member, product: products(:yoga_monthly), amount: 10, agreed_price: 100)

    get report_path("daily_cash", date: Date.current.iso8601)
    assert_select "h2", text: "Registrate in seguito", count: 0
    assert_select "h2", text: "Mattina"
    assert_select "h2", text: "Pomeriggio"
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

  test "current month lists days up to today only" do
    get reports_path
    dates = controller.instance_variable_get(:@daily_reports).map(&:date)
    assert_equal Date.current, dates.first
    assert_equal Date.current.beginning_of_month, dates.last
  end

  test "month without cash shows the empty state" do
    Sale.delete_all
    get reports_path(month: "2020-02")
    assert_match "Nessun report in questo mese", response.body
    assert_equal 29, controller.instance_variable_get(:@daily_reports).size
  end
end
