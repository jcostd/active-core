# colonne mai lette né scritte dal codice
class RemoveUnusedTrackingColumns < ActiveRecord::Migration[8.1]
  def change
    remove_column :subscriptions, :suspension_days_count, :integer, default: 0, null: false
    remove_column :access_logs, :medical_certificate_valid, :boolean, default: false, null: false
  end
end
