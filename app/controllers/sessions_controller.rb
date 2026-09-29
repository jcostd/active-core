class SessionsController < ApplicationController
  layout "unauthenticated"

  allow_unauthenticated_access only: %i[ new create ]
  skip_before_action :confine_kiosk_user, only: :destroy
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Troppi tentativi, riprova più tardi." }

  def new
  end

  def create
    if user = User.kept.authenticate_by(username: params[:username], password: params[:password])
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Username o password non corretti."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other,
                alert: ("Sessione scaduta per inattività." if params[:reason] == "idle")
  end
end
