class UsersController < ApplicationController
  include Filterable

  before_action :require_admin, except: %i[ show edit update ]
  before_action :set_user, only: %i[ show edit update destroy ]
  before_action :require_self_or_admin, only: %i[ show edit update ]

  layout "modal", only: [ :new, :create, :edit, :update ]

  def index
    @total_active_users = User.kept.count
    @pagy, @users = pagy(
      User
        .apply_filters(filter_params)
    )
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
      turbo_refresh_or_redirect_to users_path, notice: "Utente creato con successo."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    attrs = user_params
    attrs = attrs.except(:password, :password_confirmation) if attrs[:password].blank?

    if @user.update(attrs)
      turbo_refresh_or_redirect_to user_path(@user), notice: "Profilo utente aggiornato."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @user != current_user && @user.discard!
      turbo_refresh_or_redirect_to users_path, status: :see_other, notice: "Utente archiviato."
    else
      turbo_refresh_or_redirect_to users_path, status: :see_other, alert: "Impossibile archiviare utente."
    end
  end

  private
    def set_user
      @user = User.kept.find(params[:id])
    end

    def require_self_or_admin
      return if current_user.admin? || @user == current_user
      redirect_to root_path, alert: "Non disponi dei permessi necessari per accedere a questa sezione."
    end

    def user_params
      permitted = %i[ first_name last_name username email_address password password_confirmation ]
      permitted << :role if current_user.admin?

      params.expect(user: permitted)
    end

    def filter_params
      params.permit(:query, :sort).merge(role: params[:role])
    end
end
