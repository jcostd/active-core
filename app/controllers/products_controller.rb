class ProductsController < ApplicationController
  include Filterable

  before_action :require_admin
  before_action :set_product, only: [ :show, :edit, :update, :destroy ]

  layout "modal", only: [ :new, :create, :edit, :update ]

  def index
    @total_active_products = Product.kept.count
    @pagy, @products = pagy(
      Product
        .apply_filters(filter_params)
        .includes(:disciplines)
    )
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
      turbo_refresh_or_redirect_to products_path, notice: "Prodotto creato correttamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @product.update(product_params)
      turbo_refresh_or_redirect_to products_path, notice: "Prodotto aggiornato."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @product.discard!
    turbo_refresh_or_redirect_to products_path, notice: "Prodotto archiviato."
  end

  private
    def set_product
      @product = Product.find(params[:id])
    end

    def product_params
      params.expect(product: [ :name, :price, :duration_days, :accounting_category, discipline_ids: [] ])
    end

    def filter_params
      params.permit(:query, :sort)
    end
end
