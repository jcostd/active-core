# registro presenze mensile: una riga per socio, disciplina e mese.
# Lo storico degli ingressi diventa una presenza per ogni mese in cui il socio è entrato.
class CreateAttendances < ActiveRecord::Migration[8.1]
  class Attendance < ActiveRecord::Base; end

  def up
    create_table :attendances do |t|
      t.references :member, null: false, foreign_key: true, index: false
      t.references :discipline, null: false, foreign_key: true, index: false
      t.references :marked_by, null: false, foreign_key: { to_table: :users }
      t.date :month, null: false
      t.timestamps
    end
    add_index :attendances, %i[discipline_id month member_id], unique: true
    add_index :attendances, %i[member_id month]

    rows = select_rows("SELECT member_id, discipline_id, checkin_by_user_id, entered_at FROM access_logs " \
                       "WHERE discipline_id IS NOT NULL ORDER BY entered_at")
    self.class.attendances_from(rows).each_slice(500) { Attendance.insert_all(it) }
  end

  def down
    drop_table :attendances
  end

  # il primo ingresso del mese (ora di Roma) decide chi ha segnato la presenza e quando
  def self.attendances_from(rows)
    rows.each_with_object({}) do |(member_id, discipline_id, user_id, entered_at), attendances|
      entered_at = Time.find_zone("UTC").parse(entered_at.to_s).in_time_zone("Rome")
      attendances[[ member_id, discipline_id, entered_at.to_date.beginning_of_month ]] ||= [ user_id, entered_at ]
    end.map do |(member_id, discipline_id, month), (user_id, entered_at)|
      { member_id:, discipline_id:, marked_by_id: user_id, month:, created_at: entered_at, updated_at: entered_at }
    end
  end
end
