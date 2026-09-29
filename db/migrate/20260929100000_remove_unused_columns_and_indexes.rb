# colonne e indici che nessuno legge: lo stato delle segnalazioni (nessuna pagina le gestisce),
# l'indirizzo dei soci calcolato in SQL (spariva se mancava il CAP: ora è Member#full_address), indici già coperti da un composto o su colonne mai cercate.
# SQLite ricrea la tabella members e perde i trigger della ricerca full-text: vanno ricreati.
class RemoveUnusedColumnsAndIndexes < ActiveRecord::Migration[8.1]
  FIELDS = "first_name, last_name, fiscal_code, email_address, phone, birth_date"

  def up
    remove_index :feedbacks, :status
    remove_column :feedbacks, :status
    remove_column :feedbacks, :admin_notes

    remove_index :members, :full_address
    remove_column :members, :full_address
    restore_fts_triggers

    remove_index :product_disciplines, :product_id
    remove_index :subscriptions, :member_id
    remove_index :users, :preferences
    remove_index :sales, :receipt_code
  end

  def down
    add_index :sales, :receipt_code
    add_index :users, :preferences
    add_index :subscriptions, :member_id
    add_index :product_disciplines, :product_id

    add_column :members, :full_address, :virtual, type: :string, as: "address || ', ' || city || ' (' || zip_code || ')'"
    add_index :members, :full_address
    restore_fts_triggers

    add_column :feedbacks, :admin_notes, :text
    add_column :feedbacks, :status, :integer, default: 0, null: false
    add_index :feedbacks, :status
  end

  private
    def restore_fts_triggers
      %w[members_ai members_ad members_au].each { execute "DROP TRIGGER IF EXISTS #{it}" }

      execute <<~SQL
        CREATE TRIGGER members_ai AFTER INSERT ON members BEGIN
          INSERT INTO members_fts(rowid, #{FIELDS})
          VALUES (new.id, new.first_name, new.last_name, new.fiscal_code, new.email_address, new.phone, new.birth_date);
        END;
      SQL

      execute <<~SQL
        CREATE TRIGGER members_ad AFTER DELETE ON members BEGIN
          INSERT INTO members_fts(members_fts, rowid, #{FIELDS})
          VALUES ('delete', old.id, old.first_name, old.last_name, old.fiscal_code, old.email_address, old.phone, old.birth_date);
        END;
      SQL

      execute <<~SQL
        CREATE TRIGGER members_au AFTER UPDATE ON members BEGIN
          INSERT INTO members_fts(members_fts, rowid, #{FIELDS})
          VALUES ('delete', old.id, old.first_name, old.last_name, old.fiscal_code, old.email_address, old.phone, old.birth_date);
          INSERT INTO members_fts(rowid, #{FIELDS})
          VALUES (new.id, new.first_name, new.last_name, new.fiscal_code, new.email_address, new.phone, new.birth_date);
        END;
      SQL

      execute "INSERT INTO members_fts(members_fts) VALUES('rebuild')"
    end
end
