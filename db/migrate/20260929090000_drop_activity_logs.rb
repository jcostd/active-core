# il registro automatico delle modifiche non lo leggeva nessuno: la vendita è già la sua registrazione
class DropActivityLogs < ActiveRecord::Migration[8.1]
  def up
    drop_table :activity_logs
  end

  def down
    create_table :activity_logs do |t|
      t.string :action, null: false
      t.json :changes_set, default: {}
      t.references :subject, polymorphic: true, null: false
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :activity_logs, %i[user_id created_at]
  end
end
