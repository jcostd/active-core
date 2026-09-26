class ReportsController < ApplicationController
  include Filterable, SafeDateParsing

  before_action :require_admin

  def index
    @date = parse_month_param(params[:month])
    @month_range = @date.beginning_of_month..@date.end_of_month

    # divisione mattina/pomeriggio in Ruby (fuso di Roma), non con 'localtime' di SQLite
    sales_by_day = Sale.kept
                       .where(sold_on: @month_range, payment_method: :cash)
                       .select(:id, :sold_on, :created_at, :amount_cents)
                       .group_by(&:sold_on)

    # i giorni futuri del mese corrente non hanno incassi da mostrare
    days = @month_range.first..[ @month_range.last, Date.current ].min
    @daily_reports = days.map { DailyCash.for(it, sales: sales_by_day.fetch(it, [])) }.reverse
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
