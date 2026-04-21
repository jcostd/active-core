class ReportsController < ApplicationController
  include Filterable, SafeDateParsing

  def index
    @date = parse_month_param(params[:month])
    @month_range = @date.beginning_of_month..@date.end_of_month

    stats_query = Sale.kept
                    .where(sold_on: @month_range, payment_method: :cash)
                    .group(:sold_on)
                    .pluck(
                      :sold_on,
                      Arel.sql("SUM(CASE WHEN CAST(strftime('%H', datetime(created_at, 'localtime')) AS INTEGER) < 14 THEN amount_cents ELSE 0 END)"),
                      Arel.sql("SUM(CASE WHEN CAST(strftime('%H', datetime(created_at, 'localtime')) AS INTEGER) >= 14 THEN amount_cents ELSE 0 END)"),
                      Arel.sql("SUM(amount_cents)"),
                      Arel.sql("COUNT(id)")
                    )

    stats_by_date = stats_query.each_with_object({}) do |(date, morning, afternoon, total, count), hash|
      hash[date] = {
        morning: morning || 0,
        afternoon: afternoon || 0,
        total: total || 0,
        count: count || 0
      }
    end

    @daily_reports = @month_range.map do |date|
      DailyCash.for(date, stats: stats_by_date[date] || { morning: 0, afternoon: 0, total: 0, count: 0 })
    end.reverse

    @monthly_total = @daily_reports.sum(&:total_cents) / 100.0

    @keys = params.slice(:month).permit!.to_h.reject { |_, v| v.blank? || v == Date.current.strftime("%Y-%m") }
  end

  def show
    @date = parse_date_param(params[:date])

    case params[:report_type]
    when "daily_cash"
      daily_sales = Sale.kept
                      .where(sold_on: @date, payment_method: :cash)
                      .includes(:member)
                      .order(:created_at)

      @daily_cash = DailyCash.for(@date, sales: daily_sales)
    else
      redirect_to reports_path, alert: "Tipo di report non valido."
    end
  end
end
