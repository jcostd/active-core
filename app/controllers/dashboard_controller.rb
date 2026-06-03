class DashboardController < ApplicationController
  def index
    @daily_cash = DailyCash.current

    @today_accesses_count = AccessLog.where(entered_at: Time.current.beginning_of_day..Time.current.end_of_day).count

    @expiring_subscriptions = Subscription.kept
                                .includes(:member)
                                .where(end_date: Date.current..7.days.from_now)
                                .order(end_date: :asc)
                                .limit(5)

    @expiring_count = Subscription.kept.where(end_date: Date.current..7.days.from_now).count

    @recent_accesses = AccessLog.includes(:member, :discipline)
                         .order(entered_at: :desc)
                         .limit(5)

    @recent_sales = Sale.kept
                      .includes(:member, subscription: :product)
                      .order(created_at: :desc)
                      .limit(5)
  end
end
