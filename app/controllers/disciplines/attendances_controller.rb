# la segreteria corregge il registro dalla pagina Iscritti: il mese in corso chiunque, quelli chiusi l'admin.
# Si torna alla pagina da cui si è partiti: stessi filtri, stessa pagina, e Turbo mantiene lo scroll
class Disciplines::AttendancesController < ApplicationController
  include SafeDateParsing

  before_action :set_discipline

  def create
    month = parse_month_param(params[:month])
    attendance = @discipline.attendances.new(member: Member.find(params[:member_id]), month:, marked_by: current_user)

    if attendance.save
      flash[:notice] = "#{attendance.member.full_name} è nel registro di #{l(attendance.month, format: "%B %Y")}."
    else
      flash[:alert] = attendance.errors.full_messages.to_sentence
    end

    redirect_back_or_to discipline_members_path(@discipline, month: month.strftime("%Y-%m")), status: :see_other
  end

  def destroy
    attendance = @discipline.attendances.find(params[:id])

    if attendance.editable_by?(current_user)
      attendance.destroy!
      flash[:notice] = "#{attendance.member.full_name} non è più nel registro di #{l(attendance.month, format: "%B %Y")}."
    else
      flash[:alert] = "Il registro di #{l(attendance.month, format: "%B %Y")} è chiuso: può correggerlo solo un amministratore."
    end

    redirect_back_or_to discipline_members_path(@discipline, month: attendance.month.strftime("%Y-%m")), status: :see_other
  end

  private
    def set_discipline
      @discipline = Discipline.find(params[:discipline_id])
    end
end
