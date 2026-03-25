class DisciplinesController < ApplicationController
  before_action :set_discipline, only: [ :show, :edit, :update, :destroy ]

  def index
    @pagy, @disciplines = pagy(Discipline.kept.order(:name))
  end

  def show
    @related_products = @discipline.products.kept
  end

  def new
    @discipline = Discipline.new(
      requires_medical_certificate: true,
      requires_membership: true
    )

    render layout: "modal"
  end

  def create
    @discipline = Discipline.new(discipline_params)

    if @discipline.save
      redirect_to disciplines_path, notice: t(".created", default: "Disciplina creata con successo.")
    else
      render :new, layout: "modal", status: :unprocessable_entity
    end
  end

  def edit
    render layout: "modal"
  end

  def update
    if @discipline.update(discipline_params)
      redirect_to disciplines_path, notice: t(".updated", default: "Disciplina aggiornata.")
    else
      render :edit, layout: "modal", status: :unprocessable_entity
    end
  end

  def destroy
    if @discipline.discard!
      redirect_to disciplines_path, notice: t(".discarded", default: "Disciplina archiviata.")
    else
      redirect_to disciplines_path, alert: t(".error", default: "Impossibile archiviare.")
    end
  end

  private
    def set_discipline
      @discipline = Discipline.find(params[:id])
    end

    def discipline_params
      params.require(:discipline).permit(:name, :requires_medical_certificate, :requires_membership)
    end
end
