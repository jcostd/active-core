class Kiosk::MemberSearchesController < Kiosk::BaseController
  layout false

  def index
    @discipline = Discipline.kept.find(params[:discipline_id])

    if params[:query].present?
      @members = Member.kept.search_text(params[:query], columns: %i[first_name last_name]).limit(10)
    else
      @members = Member.none
    end
  end
end
