class AccessLogsController < ApplicationController
  include Filterable

  before_action :require_admin
  before_action :set_access_log, only: [:destroy]

  def index
    @total_accesses = AccessLog.count
    @pagy, @access_logs = pagy(
      AccessLogsQuery.new(filter_params).results.includes(:member, :discipline, :checkin_by_user)
    )
  end

  def new
    @access_log = AccessLog.new
  end

  def destroy
    @access_log.destroy
    redirect_to access_logs_path, status: :see_other, notice: "Accesso annullato con successo."
  end

  private
    def set_access_log
      @access_log = AccessLog.find(params[:id])
    end

    def filter_params
      params.permit(:query, :sort, :status, :discipline_id)
    end
end
