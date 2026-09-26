# Dopo ogni modifica riavviare il server.

# Parametri filtrati dai log, con corrispondenza parziale (passw copre password).
# Limita la diffusione di dati sensibili e personali.
# Sintassi supportata: documentazione di ActiveSupport::ParameterFilter.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :fiscal_code, :phone, :birth_date, :address
]
