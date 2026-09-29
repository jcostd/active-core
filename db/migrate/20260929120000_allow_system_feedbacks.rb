# segnalazioni senza utente: le scrive il sistema (manutenzione del database) per lo sviluppatore
class AllowSystemFeedbacks < ActiveRecord::Migration[8.1]
  def change
    change_column_null :feedbacks, :user_id, true
  end
end
