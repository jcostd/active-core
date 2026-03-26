class SalesController < ApplicationController
  before_action :require_admin, only: [ :index ]
  before_action :set_sale, only: [ :show, :destroy ]

  # 1. IL LAYOUT: Diciamo a Rails di usare il layout "pos" invece di quello standard
  layout "pos", only: [ :new, :create ]

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
    # 2. Inizializziamo la vendita. sale_params_for_build passa i dati se stiamo
    # facendo autosubmit, altrimenti passa un hash vuoto al primo caricamento.
    @sale = Sale.new(sale_params_for_build)

    # Valori di default
    @sale.user = current_user
    @sale.sold_on ||= Date.current
    @sale.member_id ||= params[:member_id]

    # 3. LA MAGIA: Chiediamo al modello di autoconfigurarsi.
    # Il controller non sa NULLA di come si calcolano prezzi o date.
    @sale.prepare_draft(
      renew_subscription_id: params[:renew_subscription_id],
      manual_start_date: params.dig(:sale, :subscription_attributes, :start_date)
    )
  end

  def create
    @sale = Sale.new(sale_params)
    @sale.user = current_user

    if @sale.save
      redirect_to sale_path(@sale), notice: t(".created", default: "Vendita registrata con successo.")
    else
      # Se c'è un errore di validazione, dobbiamo ri-preparare la bozza per
      # assicurarci che la UI abbia i calcoli live corretti prima di renderizzare
      @sale.prepare_draft(
        manual_start_date: params.dig(:sale, :subscription_attributes, :start_date)
      )
      render :new, status: :unprocessable_entity
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
