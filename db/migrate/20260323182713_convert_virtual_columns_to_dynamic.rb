class ConvertVirtualColumnsToDynamic < ActiveRecord::Migration[8.1]
  def up
    # Utenti: nome completo calcolato al volo
    change_column :users, :full_name, :virtual, type: :string, as: "first_name || ' ' || last_name", stored: false

    # Soci: nome e indirizzo completi calcolati al volo
    change_column :members, :full_name, :virtual, type: :string, as: "first_name || ' ' || last_name", stored: false
    change_column :members, :full_address, :virtual, type: :string, as: "address || ', ' || city || ' (' || zip_code || ')'", stored: false
  end

  def down
    change_column :users, :full_name, :virtual, type: :string, as: "first_name || ' ' || last_name", stored: true
    change_column :members, :full_name, :virtual, type: :string, as: "first_name || ' ' || last_name", stored: true
    change_column :members, :full_address, :virtual, type: :string, as: "address || ', ' || city || ' (' || zip_code || ')'", stored: true
  end
end
