# il check-in per lezione è sostituito dal registro mensile: lo storico è già nelle presenze (CreateAttendances)
class DropAccessLogs < ActiveRecord::Migration[8.1]
  def up
    drop_table :access_logs
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
