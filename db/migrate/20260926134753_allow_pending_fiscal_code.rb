# CF vuoto = "da completare" (socio senza codice fiscale al momento dell'iscrizione).
# SQLite ricrea la tabella per cambiare NOT NULL e perde i trigger della ricerca full-text:
# vanno ricreati, altrimenti l'indice members_fts smette di aggiornarsi.
class AllowPendingFiscalCode < ActiveRecord::Migration[8.1]
  def up
    change_column_null :members, :fiscal_code, true
    restore_fts_triggers
  end

  def down
    change_column_null :members, :fiscal_code, false
    restore_fts_triggers
  end

  private
    FIELDS = "first_name, last_name, fiscal_code, email_address, phone, birth_date"

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
