# utente fisso dell'iPad del kiosk; la password casuale la reimposta l'amministratore
class CreateKioskUser < ActiveRecord::Migration[8.1]
  class User < ActiveRecord::Base
    has_secure_password
  end

  def up
    return if User.exists?(role: 2)

    User.create!(username: "kiosk", first_name: "Kiosk", last_name: "Accessi", email_address: "kiosk@system.local",
                 role: 2, password: SecureRandom.base58(24))
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
