class MembersController < ApplicationController
  include Filterable

  before_action :require_admin, only: :destroy
  before_action :set_member, only: %i[ show edit update destroy ]

  layout "modal", only: [ :new, :edit ]

  def index
    @total_active_members = Member.kept.count
    @pagy, @members = pagy(
      Member
        .apply_filters(filter_params)
        .includes(subscriptions: [ :product, :sales ])
    )
    Subscription.preload_renewed(@members.flat_map(&:subscriptions))
  end

  def show
    @active_subscriptions = @member.subscriptions.kept
                              .includes(:product, :sales)
                              .select { |s| s.end_date >= Date.current }
                              .sort_by { |s| s.start_date || Date.current }
    Subscription.preload_renewed(@active_subscriptions)
  end

  def new
    @member = Member.new
  end

  def create
    @member = Member.new(member_params)

    if @member.save
      turbo_refresh_or_redirect_to @member, notice: "Socio creato con successo."
    else
      render :new, layout: "modal", status: :unprocessable_entity
    end
  end

  def edit;  end

  def update
    if @member.update(member_params)
      turbo_refresh_or_redirect_to @member, notice: "Socio aggiornato con successo."
    else
      render :edit, layout: "modal", status: :unprocessable_entity
    end
  end

  def destroy
    @member.discard!
    turbo_refresh_or_redirect_to members_path, status: :see_other, notice: "Socio archiviato correttamente."
  end

  private
    def set_member
      @member = Member.find(params[:id])
    end

    def member_params
      params.expect(member: %i[
        first_name last_name fiscal_code fiscal_code_pending birth_date
        email_address phone address city zip_code
        medical_certificate_expiry
      ])
    end

    def filter_params
      params.permit(:query, :sort, :membership_status, :med_cert)
    end
end
