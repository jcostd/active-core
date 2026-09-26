class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: "Reimposta la tua password", to: user.email_address
  end
end
