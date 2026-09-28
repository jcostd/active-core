class DashboardController < ApplicationController
  def index
    @daily_cash = DailyCash.for(Date.current)

    @expiring_subscriptions = Subscription.expiring.includes(:member).order(end_date: :asc).limit(5).load
    @expiring_count = Subscription.expiring.count

    # frequentano questo mese senza abbonamento della disciplina: da regolarizzare in segreteria
    @unenrolled = Attendance.in_month(Date.current).unenrolled
                            .joins(:member).merge(Member.kept)
                            .order(members: { last_name: :asc, first_name: :asc })
                            .includes(:member, :discipline).load

    @recent_sales = Sale.kept
                      .includes(:member, subscription: :product)
                      .order(created_at: :desc)
                      .limit(5)
                      .load
  end
end
