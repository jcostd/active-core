# l'email degli utenti serviva solo al reset della password, che non c'è più: si entra con lo username
class RemoveEmailAddressFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_index :users, :email_address, unique: true, where: "discarded_at IS NULL"
    remove_column :users, :email_address, :string
  end
end
