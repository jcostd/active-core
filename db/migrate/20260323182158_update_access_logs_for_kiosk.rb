class UpdateAccessLogsForKiosk < ActiveRecord::Migration[8.1]
  def change
    # 1. Rimuoviamo l'obbligo di abbonamento per poter registrare gli ingressi negati/scaduti
    change_column_null :access_logs, :subscription_id, true

    # 2. Aggiungiamo il tracciamento della disciplina (Sala Pesi, Karate, ecc.)
    add_reference :access_logs, :discipline, null: true, foreign_key: true

    # 3. Aggiungiamo lo stato. 0 = granted, 1 = denied_expired, 2 = denied_no_cert
    add_column :access_logs, :status, :integer, default: 0, null: false
    add_index :access_logs, :status
  end
end
