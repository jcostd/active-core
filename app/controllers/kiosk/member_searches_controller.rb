class Kiosk::MemberSearchesController < Kiosk::BaseController
  layout false

  def index
    @discipline = Discipline.kept.find(params[:discipline_id])
    @members = params[:query].present? ? Member.kept.search_text(params[:query], columns: %i[first_name last_name]).limit(10).preload(Standing::PRELOAD).to_a : []

    @marked_ids = @discipline.attendances.in_month(Attendance.current_month).where(member_id: @members.map(&:id)).pluck(:member_id).to_set
    @standings = @members.index_with { Standing.new(member: it, discipline: @discipline) }
  end
end
