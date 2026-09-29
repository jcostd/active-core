class Kiosk::DisciplinesController < Kiosk::BaseController
  def index
    @disciplines = Discipline.kept.order(:name)
  end

  # registro del mese: chi è già smarcato e chi l'istruttore dovrebbe vedere (iscritti e presenti il mese scorso)
  def show
    @discipline = Discipline.kept.find(params[:id])
    @month = Attendance.current_month

    @attendances = @discipline.attendances.in_month(@month)
                              .joins(:member).order(members: { first_name: :asc, last_name: :asc })
                              .preload(member: Standing::PRELOAD).to_a

    @pending_members = Member.kept.enrolled_in(@discipline, during: @month.all_month)
                             .or(Member.kept.attended(@discipline, @month.prev_month))
                             .where.not(id: @attendances.map(&:member_id))
                             .order(:first_name, :last_name)
                             .preload(Standing::PRELOAD).to_a

    @standings = [ *@attendances.map(&:member), *@pending_members ].index_with do
      Standing.new(member: it, discipline: @discipline, month: @month)
    end
  end
end
