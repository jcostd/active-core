class MembersController < ApplicationController
  include FilterableActions

  before_action :set_member, only: [ :edit, :update, :destroy ]

  def index
    base_scope = Member.includes(:subscriptions)

    @pagy, @members = filter_and_paginate(base_scope)
  end

  def show
    @member = Member.includes(subscriptions: :product, sales: [])
                    .find(params[:id])
  end

  def renewal_info
    @member = Member.find(params[:id])
    product = Product.find_by(id: params[:product_id])

    is_manual_input = params[:ref_date].present?

    reference_date = is_manual_input ? Date.parse(params[:ref_date]) : Date.current

    if product
      info = RenewalCalculator.new(@member, product, reference_date, manual_override: is_manual_input).call
      render json: info
    else
      render json: {}, status: :bad_request
    end
  end

  def new
    @member = Member.new
    render layout: "modal"
  end

  def create
    @member = Member.new(member_params)

    if @member.save
      redirect_to @member, notice: t(".created", default: "Socio creato con successo.")
    else
      render :new, layout: "modal", status: :unprocessable_entity
    end
  end

  def edit
    render layout: "modal"
  end

  def update
    if @member.update(member_params)
      redirect_to @member, notice: t(".updated", default: "Socio aggiornato con successo.")
    else
      render :edit, layout: "modal", status: :unprocessable_entity
    end
  end

  def destroy
    if @member.discard!
      redirect_to members_path, status: :see_other, notice: t(".discarded", default: "Socio archiviato correttamente.")
    else
      redirect_to members_path, status: :see_other, alert: t(".discard_error", default: "Impossibile archiviare il socio.")
    end
  end

  private
    def set_member
      @member = Member.find(params[:id])
    end

    def member_params
      params.require(:member).permit(
        :first_name,
        :last_name,
        :fiscal_code,
        :birth_date,
        :email_address,
        :phone,
        :address,
        :city,
        :zip_code,
        :medical_certificate_expiry
      )
    end
end
