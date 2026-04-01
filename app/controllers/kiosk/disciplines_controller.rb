class Kiosk::DisciplinesController < Kiosk::BaseController
  def index
    @disciplines = Discipline.kept.order(:name)
  end

  def show
    @discipline = Discipline.kept.find(params[:id])

    @expected_members = Member.kept
                          .joins(subscriptions: { product: :disciplines })
                          .where(disciplines: { id: @discipline.id })
                          .where("subscriptions.start_date <= :today AND subscriptions.end_date >= :today", today: Date.current)
                          .where(subscriptions: { discarded_at: nil })
                          .distinct
                          .order(:first_name, :last_name)
  end
end
