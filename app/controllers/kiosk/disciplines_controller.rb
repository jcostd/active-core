class Kiosk::DisciplinesController < Kiosk::BaseController
  def index
    @disciplines = Discipline.kept.order(:name)
  end

  def show
    @discipline = Discipline.kept.find(params[:id])

    @today_accesses = @discipline.access_logs
                        .where(entered_at: Time.current.all_day)
                        .includes(:member)
                        .order(entered_at: :desc)

    checked_in_member_ids = @today_accesses.map(&:member_id)


    @pending_members = Member.kept
                         .joins(subscriptions: { product: :disciplines })
                         .where(disciplines: { id: @discipline.id })
                         .where("subscriptions.start_date <= :today AND subscriptions.end_date >= :today", today: Date.current)
                         .where(subscriptions: { discarded_at: nil })
                         .distinct

    if checked_in_member_ids.any?
      @pending_members = @pending_members.where.not(id: checked_in_member_ids)
    end

    @pending_members = @pending_members.order(:first_name, :last_name)
  end
end
