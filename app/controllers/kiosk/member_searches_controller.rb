class Kiosk::MemberSearchesController < Kiosk::BaseController
  layout false

  def index
    @discipline = Discipline.kept.find(params[:discipline_id])

    if params[:query].present?
      @members = Member.kept.search_text(params[:query], columns: %i[first_name last_name]).limit(10)
      @marked_ids = @discipline.attendances.in_month(Attendance.current_month).where(member: @members).pluck(:member_id).to_set
    else
      @members = Member.none
    end
  end
end
