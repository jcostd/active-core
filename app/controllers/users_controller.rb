class UsersController < ApplicationController
  include Filterable

  before_action :set_user, only: [ :show, :edit, :update, :destroy ]

  layout "modal", only: [ :new, :create, :edit, :update ]

  def index
    @total_active_users = User.kept.count
    @pagy, @users = pagy(UsersQuery.new(filter_params).results)
  end

  def show
    @sales_count = @user.sales.count
  end

  def new
    @user = User.new(role: :staff)
  end

  def create
    @user = User.new(user_params)

    if @user.save
      turbo_refresh_or_redirect_to users_path, notice: t(".created", default: "Utente creato con successo.")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    upd_params = user_params
    if upd_params[:password].blank?
      upd_params.delete(:password)
      upd_params.delete(:password_confirmation)
    end

    if @user.update(upd_params)
      turbo_refresh_or_redirect_to users_path, notice: t(".updated", default: "Profilo utente aggiornato.")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @user != current_user && @user.discard!
      turbo_refresh_or_redirect_to users_path, status: :see_other, notice: t(".discarded", default: "Utente archiviato.")
    else
      turbo_refresh_or_redirect_to users_path, status: :see_other, alert: t(".error", default: "Impossibile archiviare utente.")
    end
  end

  private
    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      permitted_params = [
        :first_name, :last_name, :username,
        :email_address, :password, :password_confirmation
      ]
      permitted_params << :role if current_user&.admin?

      params.require(:user).permit(permitted_params)
    end

    def filter_params
      params.permit(:query, :sort, :state, :role)
    end
end
