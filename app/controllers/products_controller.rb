class ProductsController < ApplicationController
  include Filterable

  before_action :require_admin
  before_action :set_product, only: [ :show, :edit, :update, :destroy ]

  layout "modal", only: [ :new, :create, :edit, :update ]

  def index
    @total_active_products = Product.kept.count
    @pagy, @products = pagy(ProductsQuery.new(filter_params).results.includes(:disciplines))
  end

  def show; end

  def new
    initial_disciplines = params[:discipline_id] ? [ params[:discipline_id] ] : []

    @product = Product.new(
      discipline_ids: initial_disciplines,
      accounting_category: :institutional,
      duration_days: 30
    )
  end

  def create
    @product = Product.new(product_params)

    if @product.save
      turbo_refresh_or_redirect_to products_path, notice: t(".created", default: "Prodotto creato correttamente.")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @product.update(product_params)
      turbo_refresh_or_redirect_to products_path, notice: t(".updated", default: "Prodotto aggiornato.")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @product.discard!
      turbo_refresh_or_redirect_to products_path, notice: t(".discarded", default: "Prodotto archiviato.")
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
        :entry_limit,
        discipline_ids: []
      )
    end

    def filter_params
      params.permit(:query, :sort, :state, :accounting_category)
    end
end
