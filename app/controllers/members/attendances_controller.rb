class Members::AttendancesController < ApplicationController
  before_action :set_member

  def index
    @pagy, @attendances = pagy(@member.attendances.joins(:discipline).order(month: :desc, disciplines: { name: :asc })
                                      .preload(:discipline, :marked_by))
    @standings = @attendances.index_with { Standing.new(member: @member, discipline: it.discipline, month: it.month) }
  end

  private
    def set_member
      @member = Member.preload(Standing::PRELOAD).find(params[:member_id])
    end
end
