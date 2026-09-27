class DashboardController < ApplicationController
  def index
    @daily_cash = DailyCash.for(Date.current)

    @today_accesses_count = AccessLog.today.count

    @expiring_subscriptions = Subscription.expiring.includes(:member).order(end_date: :asc).limit(5).load
    @expiring_count = Subscription.expiring.count

    @recent_accesses = AccessLog.includes(:member, :discipline)
                         .order(entered_at: :desc)
                         .limit(5)
                         .load

    @recent_sales = Sale.kept
                      .includes(:member, subscription: :product)
                      .order(created_at: :desc)
                      .limit(5)
                      .load
  end
end
