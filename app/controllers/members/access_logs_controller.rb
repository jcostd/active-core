class Members::AccessLogsController < ApplicationController
  before_action :set_member

  def index
    @pagy, @access_logs = pagy(@member.access_logs.order(created_at: :desc))
  end

  private
    def set_member
      @member = Member.find(params[:member_id])
    end
end
