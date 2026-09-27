class PasswordsController < ApplicationController
  layout "unauthenticated"

  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_password_path, alert: "Troppi tentativi, riprova più tardi." }

  def new
  end

  def create
    if user = User.kept.find_by(email_address: params[:email_address])
      PasswordsMailer.reset(user).deliver_later
    end

    redirect_to new_session_path, notice: "Se l'indirizzo è registrato, riceverai le istruzioni per reimpostare la password."
  end

  def edit
  end

  def update
    @user.assign_attributes(params.permit(:password, :password_confirmation))

    if @user.save(context: :password_reset)
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: "Password reimpostata."
    else
      redirect_to edit_password_path(params[:token]), alert: @user.errors.full_messages.to_sentence
    end
  end

  private
    def set_user_by_token
      @user = User.kept.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      redirect_to new_password_path, alert: "Il link per reimpostare la password non è valido o è scaduto."
    end
end
