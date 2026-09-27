class Kiosk::DisciplinesController < Kiosk::BaseController
  def index
    @disciplines = Discipline.kept.order(:name)
  end

  def show
    @discipline = Discipline.kept.find(params[:id])

    @today_accesses = @discipline
                        .access_logs
                        .today
                        .includes(:member)
                        .order(entered_at: :desc)

    @pending_members = Member.kept
                         .joins(:subscriptions)
                         .merge(Subscription.kept.for_discipline(@discipline))
                         .where(subscriptions: {
                                  end_date: 2.months.ago.beginning_of_month..,
                                  start_date: ..1.month.from_now.end_of_month
                                })
                         .without_recent_checkin_for(@discipline)
                         .distinct
                         .order(:first_name, :last_name)
                         .preload(subscriptions: { product: :disciplines }) # preload: tutti gli abbonamenti, quota compresa
                         .to_a
    Subscription.preload_renewed(@pending_members.flat_map(&:subscriptions))
    # una valutazione per socio, usata sia dalla chiave di cache sia dalla card
    @policies = @pending_members.index_with { AccessPolicy.new(member: it, discipline: @discipline).evaluate! }
  end
end
