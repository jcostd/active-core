class UsersController < ApplicationController
  before_action :set_user, only: [ :show, :edit, :update, :destroy ]

  def index
    @pagy, @users = pagy(User.kept.order(role: :desc, last_name: :asc))
  end

  def show
    @sales_count = @user.sales.count
    @checkins_count = @user.checkins_performed.count
  end

  def new
    @user = User.new(role: :staff)
    render layout: "modal"
  end

  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to users_path, notice: t(".created", default: "Utente creato con successo.")
    else
      render :new, layout: "modal", status: :unprocessable_entity
    end
  end

  def edit
    render layout: "modal"
  end

  def update
    upd_params = user_params
    if upd_params[:password].blank?
      upd_params.delete(:password)
      upd_params.delete(:password_confirmation)
    end

    if @user.update(upd_params)
      redirect_to users_path, notice: t(".updated", default: "Profilo utente aggiornato.")
    else
      render :edit, layout: "modal", status: :unprocessable_entity
    end
  end

  def destroy
    if @user == current_user
      redirect_to users_path, alert: "Non puoi archiviare il tuo stesso account."
      return
    end

    if @user.discard!
      redirect_to users_path, notice: t(".discarded", default: "Utente archiviato.")
    else
      redirect_to users_path, alert: t(".error", default: "Impossibile archiviare utente.")
    end
  end

  private
    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      permitted_params = [
        :first_name,
        :last_name,
        :username,
        :email_address,
        :password,
        :password_confirmation ]

      permitted_params << :role if current_user&.admin?

      params.require(:user).permit(permitted_params)
    end
end
