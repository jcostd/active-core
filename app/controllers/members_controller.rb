class MembersController < ApplicationController
  before_action :set_member, only: [ :show, :edit, :update, :destroy ]

  def index
    query_results = MembersQuery.new(filter_params).results

    @total_active_members = Member.kept.count

    @pagy, @members = pagy(query_results.includes(:subscriptions))
    @is_filtering = filter_params.to_h.except(:sort).reject { |_, v| v.blank? }.any?
  end

  def show
    @member = Member.find(params[:id])
    @active_subscriptions = @member.active_subscriptions
    @recent_sales = @member.recent_sales
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
        :first_name, :last_name, :fiscal_code, :birth_date,
        :email_address, :phone, :address, :city, :zip_code,
        :medical_certificate_expiry
      )
    end

    def filter_params
      params.permit(:query, :sort, :membership_status, :med_cert, :state)
    end
end
