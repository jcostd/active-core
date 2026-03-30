class SalesController < ApplicationController
  before_action :require_admin, only: [ :index ]
  before_action :set_sale, only: [ :show, :destroy ]

  layout -> { turbo_frame_request_id == "pos_form_frame" ? false : "modal" }, only: [ :new, :create ]

  def index
    scope = Sale.kept
                .includes(:member, :user)
                .order(sold_on: :desc, created_at: :desc)
    @pagy, @sales = pagy(scope)
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
    @sale = Sale.new(sale_params_for_build)

    @sale.prepare_draft(
      autosubmit: params.has_key?(:sale),
      preset_member_id: params[:member_id],
      renew_subscription_id: params[:renew_subscription_id],
      previous_product_id: params[:previous_product_id],
      previous_member_id: params[:previous_member_id]
    )
  end

  def create
    @sale = Sale.new(sale_params)
    @sale.user = current_user

    if @sale.save
      redirect_to sale_path(@sale), notice: t(".created", default: "Vendita registrata con successo.")
    else
      @sale.prepare_draft(
        manual_start_date: params.dig(:sale, :subscription_attributes, :start_date)
      )

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

    # Questo ci serve perché la action `new` ora viene chiamata in due modi:
    # 1. Link normale (params[:sale] non esiste -> solleverebbe errore con `require`)
    # 2. Autosubmit di Turbo (params[:sale] esiste e vogliamo i dati)
    def sale_params_for_build
      params.has_key?(:sale) ? sale_params : {}
    end

    def sale_params
      params.require(:sale).permit(
        :member_id,
        :product_id,
        :amount,
        :payment_method,
        :sold_on,
        :notes,
        subscription_attributes: [ :start_date ]
      )
    end
end
