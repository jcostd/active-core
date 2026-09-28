class Kiosk::AttendancesController < Kiosk::BaseController
  FLASH_TYPES = { ok: :success, warning: :info, error: :error }.freeze

  before_action :set_discipline

  def create
    member = Member.kept.find(params[:member_id])
    attendance = @discipline.attendances.new(member:, marked_by: current_user)

    if attendance.save
      standing = Standing.new(member:, discipline: @discipline)
      flash[FLASH_TYPES.fetch(standing.tone)] = marked_message(member, standing)
    else
      flash[:error] = "Impossibile smarcare #{member.first_name}: #{attendance.errors.full_messages.to_sentence}"
    end

    redirect_to kiosk_discipline_path(@discipline)
  end

  def destroy
    attendance = @discipline.attendances.find(params[:id])

    if attendance.editable_by?(current_user)
      attendance.destroy!
      flash[:success] = "#{attendance.member.first_name} non è più nel registro di #{l(attendance.month, format: "%B")}."
    else
      flash[:error] = "Il registro di #{l(attendance.month, format: "%B %Y")} è chiuso: può correggerlo solo un amministratore."
    end

    redirect_to kiosk_discipline_path(@discipline), status: :see_other
  end

  private
    def set_discipline
      @discipline = Discipline.kept.find(params[:discipline_id])
    end

    # si smarca sempre: il messaggio dice cosa deve sistemare la segreteria
    def marked_message(member, standing)
      notes = [ (standing.label unless standing.key == :paid), ("Certificato scaduto" if standing.certificate_missing?) ].compact
      message = "#{member.first_name} è nel registro di #{l(standing.month, format: "%B")}"
      notes.any? ? "#{message}: #{notes.join(", ")}" : message
    end
end
