class Kiosk::AccessLogsController < Kiosk::BaseController
  def create
    @discipline = Discipline.find(params[:discipline_id])
    @member = Member.find(params[:member_id])

    @access_log = AccessLog.new(
      member: @member,
      discipline: @discipline,
      checkin_by_user: current_user
    )

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
    @discipline = Discipline.find(params[:discipline_id])
    @access_log = @discipline.access_logs.find(params[:id])

    @access_log.destroy

    redirect_to kiosk_discipline_path(@discipline), notice: "Check-in annullato per #{@access_log.member.first_name}"
  end
end
