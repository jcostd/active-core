class ProductsController < ApplicationController
  before_action :set_product, only: [ :show, :edit, :update, :destroy ]

  def index
    @pagy, @products = pagy(Product.kept.includes(:disciplines).order(:name))
  end

  def show; end

  def new
    initial_disciplines = params[:discipline_id] ? [ params[:discipline_id] ] : []

    @product = Product.new(
      discipline_ids: initial_disciplines,
      accounting_category: :institutional,
      duration_days: 30
    )

    render layout: "modal"
  end

  def create
    @product = Product.new(product_params)

    if @product.save
      redirect_to products_path, notice: t(".created", default: "Prodotto creato correttamente.")
    else
      render :new, layout: "modal", status: :unprocessable_entity
    end
  end

  def edit
    render layout: "modal"
  end

  def update
    if @product.update(product_params)
      redirect_to products_path, notice: t(".updated", default: "Prodotto aggiornato.")
    else
      render :edit, layout: "modal", status: :unprocessable_entity
    end
  end

  def destroy
    if @product.discard!
      redirect_to products_path, notice: t(".discarded", default: "Prodotto archiviato.")
    else
      redirect_to products_path, alert: t(".error", default: "Impossibile archiviare.")
    end
  end

  private

    def set_product
      @product = Product.find(params[:id])
    end

    def product_params
      params.require(:product).permit(
        :name,
        :price,
        :duration_days,
        :accounting_category,
        discipline_ids: []
      )
    end
end
