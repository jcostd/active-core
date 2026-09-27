class SalesController < ApplicationController
  include Filterable

  before_action :require_admin, only: :index
  before_action :set_sale, only: [ :show, :destroy ]
  before_action :refuse_voided_receipt, only: :show, if: -> { request.format.pdf? }

  layout -> { turbo_frame_request_id == "pos_form_frame" ? false : "modal" }, only: [ :new, :create ]

  def index
    @total_active_sales = Sale.kept.count
    @pagy, @sales = pagy(
      Sale
        .apply_filters(filter_params)
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
                  disposition: "inline"
      end
    end
  end

  def new
    @sale = draft(Sale.new(params.key?(:sale) ? sale_params : {}))
  end

  def create
    @sale = Sale.new(sale_params)
    @sale.user = current_user

    if @sale.save
      redirect_to sale_path(@sale), notice: "Vendita registrata con successo."
    else
      @sale = draft(@sale)

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
    unless @sale.reversible_by?(current_user)
      return redirect_back(fallback_location: @sale.member, status: :see_other, alert: "Questo pagamento non è più annullabile.")
    end

    @sale.discard!
    redirect_back(fallback_location: @sale.member, status: :see_other, notice: "Pagamento annullato.")
  end

  private
    def set_sale
      @sale = Sale.find(params[:id])
    end

    # una ricevuta annullata non deve poter circolare come valida
    def refuse_voided_receipt
      redirect_to sale_path(@sale), alert: "Pagamento annullato: la ricevuta non è più stampabile." if @sale.discarded?
    end

    def draft(sale)
      context = params.permit(:member_id, :installment_for_subscription_id,
                              :previous_member_id, :previous_product_id).to_h.symbolize_keys

      Sale::Draft.new(sale, **context, override_end_date: current_user.admin? && params[:override_end_date] == "1").sale
    end

    def sale_params
      permitted_sub_attrs = [ :start_date ]

      if current_user.admin?
        permitted_sub_attrs << :end_date
        permitted_sub_attrs << :agreed_price
      end

      permitted = [ :member_id, :product_id, :amount, :payment_method, :notes, :subscription_id ]
      permitted << :sold_on if current_user.admin?

      params.expect(sale: [ *permitted, subscription_attributes: permitted_sub_attrs ])
    end

    def filter_params
      params.permit(:query, :sort, :state, :period, :payment_method, :accounting_category, :operator_id)
    end
end
