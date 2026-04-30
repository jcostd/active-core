class Kiosk::MemberSearchesController < Kiosk::BaseController
  layout false

  def index
    @discipline = Discipline.find(params[:discipline_id])

    if params[:query].present?
      @members = Member.search_text(params[:query]).limit(10)
      @checked_in_ids = @discipline.access_logs.recent_for_kiosk.pluck(:member_id)
    else
      @members = Member.none
    end
  end
end
