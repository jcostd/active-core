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
                         .with_active_subscription_for(@discipline)
                         .without_recent_checkin_for(@discipline)
                         .order(:first_name, :last_name)
  end
end
