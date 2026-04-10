class SalesController < ApplicationController
  include Filterable

  before_action :require_admin, only: [ :index ]
  before_action :set_sale, only: [ :show, :destroy ]

  layout -> { turbo_frame_request_id == "pos_form_frame" ? false : "modal" }, only: [ :new, :create ]

  def index
    @total_active_sales = Sale.kept.count
    @pagy, @sales = pagy(
      SalesQuery.new(filter_params)
        .results
        .includes(:member, :user)
    )
  end

  def show
    respond_to do |format|
      format.html
      format.pdf do
        pdf = PaymentReceiptPdf.new(@sale)
        send_data pdf.render,
                  filename: "ricevuta_#{@sale.id}_#{@sale.member.last_name}.pdf",
                  type: "application/pdf",
                  disposition: "_blank"
      end
    end
  end

  def new
    @sale = PosDraftBuilder.new(
      sale_params: sale_params_for_build,
      context_params: params
    ).build
  end

  def create
    @sale = Sale.new(sale_params)
    @sale.user = current_user

    if @sale.save
      redirect_to sale_path(@sale), notice: t(".created", default: "Vendita registrata con successo.")
    else
      @sale = PosDraftBuilder.new(
        sale_params: sale_params,
        context_params: params,
        existing_sale: @sale
      ).build

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
                   "pos_form_frame",
                   template: "sales/new",
                   layout: false
                 ), status: :unprocessable_entity
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    if @sale.discard!
      redirect_back(fallback_location: sales_path, status: :see_other, notice: "Vendita annullata/stornata.")
    else
      redirect_back(fallback_location: sales_path, status: :see_other, alert: "Impossibile annullare la vendita.")
    end
  end

  private
    def set_sale
      @sale = Sale.find(params[:id])
    end

    def sale_params_for_build
      params.has_key?(:sale) ? sale_params : {}
    end

    def sale_params
      permitted_sub_attrs = [ :start_date, :agreed_price ]

      if current_user.respond_to?(:admin?) && current_user.admin?
        permitted_sub_attrs << :end_date
      end

      params.require(:sale).permit(
        :member_id, :product_id, :amount, :payment_method,
        :sold_on, :notes, :subscription_id,
        subscription_attributes: permitted_sub_attrs
      )
    end

    def filter_params
      params.permit(:query, :sort, :payment_method)
    end
end
