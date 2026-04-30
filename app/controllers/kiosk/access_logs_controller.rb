class Kiosk::AccessLogsController < Kiosk::BaseController
  before_action :set_discipline
  before_action :set_discipline_access_log, only: [ :destroy ]
  before_action :set_member, only: [ :create ]

  def create
    @access_log = @discipline.access_logs.build(member: @member, checkin_by_user: current_user)

    if @access_log.save
      if @access_log.status == "ok"
        flash[:success] = "Check-in registrato per #{@member.first_name}"
      else
        flash[:warning] = "Check-in forzato per #{@member.first_name} (Verificare anagrafica)"
      end
    else
      flash[:error] = @access_log.errors.full_messages.to_sentence
    end

    redirect_to kiosk_discipline_path(@discipline)
  end

  def destroy
    @access_log.destroy
    redirect_to kiosk_discipline_path(@discipline), notice: "Check-in annullato per #{@access_log.member.first_name}"
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
