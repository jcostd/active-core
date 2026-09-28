# note operative delle lezioni private: maestro e atleti sono nomi scritti a mano, non soci né utenti
class CreatePrivateLessons < ActiveRecord::Migration[8.1]
  def change
    create_table :private_lessons do |t|
      t.string :teacher, null: false
      t.json :athletes, null: false, default: []
      t.datetime :held_at, null: false
      t.integer :duration_minutes, null: false
      t.text :note
      t.references :recorded_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :private_lessons, :held_at
  end
end
