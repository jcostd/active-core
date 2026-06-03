class Kiosk::AccessLogsController < Kiosk::BaseController
  before_action :set_discipline
  before_action :set_discipline_access_log, only: [ :destroy ]
  before_action :set_member, only: [ :create ]

  def create
    @access_log = @discipline.access_logs.build(member: @member, checkin_by_user: current_user)

    if @access_log.save
      case @access_log.status
      when "ok"
        flash[:success] = "Check-in registrato per #{@member.first_name}"
      when "warning"
        flash[:info] = "Check-in registrato. Nota per #{@member.first_name}: verificare certificato."
      when "error"
        flash[:error] = "ATTENZIONE: Check-in FORZATO per #{@member.first_name}. Abbonamento o Quota assente!"
      end
    else
      flash[:error] = "Impossibile registrare il check-in: " + @access_log.errors.full_messages.to_sentence
    end

    redirect_to kiosk_discipline_path(@discipline)
  end

  def destroy
    member_name = @access_log.member.first_name
    @access_log.destroy

    flash[:success] = "Check-in annullato per #{member_name}"
    redirect_to kiosk_discipline_path(@discipline)
  end

  private
    def set_discipline
      @discipline = Discipline.find(params[:discipline_id])
    end

    def set_discipline_access_log
      @access_log = @discipline.access_logs.find(params[:id])
    end

    def set_member
      @member = Member.find(params[:member_id])
    end
end
