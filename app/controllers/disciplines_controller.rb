class DisciplinesController < ApplicationController
  include Filterable

  before_action :set_discipline, only: [ :show, :edit, :update, :destroy ]

  layout "modal", only: [ :new, :create, :edit, :update ]

  def index
    @total_active_disciplines = Discipline.kept.count
    @pagy, @disciplines = pagy(
      Discipline
        .apply_filters(filter_params)
        .includes(:products)
    )
  end

  def show
    @related_products = @discipline.products.kept
  end

  def new
    @discipline = Discipline.new(
      requires_medical_certificate: true,
      requires_membership: true
    )
  end

  def create
    @discipline = Discipline.new(discipline_params)

    if @discipline.save
      turbo_refresh_or_redirect_to disciplines_path, notice: "Disciplina creata con successo."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit;  end

  def update
    if @discipline.update(discipline_params)
      turbo_refresh_or_redirect_to disciplines_path, notice: "Disciplina aggiornata."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @discipline.discard!
      turbo_refresh_or_redirect_to disciplines_path, notice: "Disciplina archiviata."
    else
      turbo_refresh_or_redirect_to disciplines_path, alert: "Impossibile archiviare."
    end
  end

  private
    def set_discipline
      @discipline = Discipline.find(params[:id])
    end

    def discipline_params
      params.require(:discipline).permit(:name, :requires_medical_certificate, :requires_membership)
    end

    def filter_params
      params.permit(:query, :sort)
    end
end
