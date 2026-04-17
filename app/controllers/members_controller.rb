class MembersController < ApplicationController
  include Filterable

  before_action :set_member, only: [ :show, :edit, :update, :destroy ]

  layout "modal", only: [ :new, :create, :edit, :update ]

  def index
    @total_active_members = Member.kept.count
    @pagy, @members = pagy(
      MembersQuery.new(filter_params)
        .results
        .includes(subscriptions: [ :product, :sales ]))
  end

  def show
    @member = Member.find(params[:id])
    @active_subscriptions = @member.active_subscriptions
    @recent_sales = @member.recent_sales
  end

  def new
    @member = Member.new
  end

  def create
    @member = Member.new(member_params)

    if @member.save
      redirect_to @member, notice: t(".created", default: "Socio creato con successo.")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit;  end

  def update
    if @member.update(member_params)
      redirect_to @member, notice: t(".updated", default: "Socio aggiornato con successo.")
    else
      render :edit, status: :unprocessable_entity
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
        :first_name, :last_name, :fiscal_code, :birth_date,
        :email_address, :phone, :address, :city, :zip_code,
        :medical_certificate_expiry
      )
    end

    def filter_params
      params.permit(:query, :sort, :membership_status, :med_cert, :state)
    end
end
