class Kiosk::AccessLogsController < Kiosk::BaseController
  FLASH_TYPES = { "ok" => :success, "warning" => :info, "error" => :error }.freeze

  before_action :set_discipline
  before_action :set_member, only: [ :create ]

  def create
    @access_log = @discipline.access_logs.build(member: @member, checkin_by_user: current_user)

    if @access_log.save
      flash[FLASH_TYPES.fetch(@access_log.status)] = check_in_message
    else
      flash[:error] = "Impossibile registrare il check-in: " + @access_log.errors.full_messages.to_sentence
    end

    redirect_to kiosk_discipline_path(@discipline)
  end

  private
    # l'ingresso non si blocca mai: il messaggio dice cosa va sistemato
    def check_in_message
      message = "Check-in registrato per #{@member.first_name}"
      message += ", da regolarizzare" if @access_log.error?
      notes = @access_log.outcome_notes
      notes.any? ? "#{message}: #{notes.join(" ")}" : message
    end

    def set_discipline
      @discipline = Discipline.kept.find(params[:discipline_id])
    end

    def set_member
      @member = Member.kept.find(params[:member_id])
    end
end
