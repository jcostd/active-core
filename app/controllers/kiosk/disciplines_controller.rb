class Kiosk::DisciplinesController < Kiosk::BaseController
  # soci proposti all'appello: iscritti da due mesi fa a fine del mese prossimo, anche se da regolarizzare
  KIOSK_WINDOW = -> { 2.months.ago.to_date.beginning_of_month..1.month.from_now.to_date.end_of_month }

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
                         .enrolled_in(@discipline, during: KIOSK_WINDOW.call)
                         .without_recent_checkin_for(@discipline)
                         .order(:first_name, :last_name)
                         .preload(subscriptions: { product: :disciplines }) # preload: tutti gli abbonamenti, quota compresa
                         .to_a
    Subscription.preload_renewed(@pending_members.flat_map(&:subscriptions))
    # una valutazione per socio, usata sia dalla chiave di cache sia dalla card
    @policies = @pending_members.index_with { AccessPolicy.new(member: it, discipline: @discipline).evaluate! }
  end
end
