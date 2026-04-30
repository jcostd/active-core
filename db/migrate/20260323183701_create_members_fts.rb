class CreateMembersFts < ActiveRecord::Migration[8.1]
  def up
    execute "DROP TRIGGER IF EXISTS members_ai"
    execute "DROP TRIGGER IF EXISTS members_ad"
    execute "DROP TRIGGER IF EXISTS members_au"
    execute "DROP TABLE IF EXISTS members_fts"

    execute <<-SQL
      CREATE VIRTUAL TABLE members_fts USING fts5(
        first_name,
        last_name,
        fiscal_code,
        email_address,
        phone,
        birth_date,
        content='members',
        content_rowid='id'
      );
    SQL

    execute <<-SQL
      CREATE TRIGGER members_ai AFTER INSERT ON members BEGIN
        INSERT INTO members_fts(rowid, first_name, last_name, fiscal_code, email_address, phone, birth_date)
        VALUES (new.id, new.first_name, new.last_name, new.fiscal_code, new.email_address, new.phone, new.birth_date);
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER members_ad AFTER DELETE ON members BEGIN
        INSERT INTO members_fts(members_fts, rowid, first_name, last_name, fiscal_code, email_address, phone, birth_date)
        VALUES ('delete', old.id, old.first_name, old.last_name, old.fiscal_code, old.email_address, old.phone, old.birth_date);
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER members_au AFTER UPDATE ON members BEGIN
        INSERT INTO members_fts(members_fts, rowid, first_name, last_name, fiscal_code, email_address, phone, birth_date)
        VALUES ('delete', old.id, old.first_name, old.last_name, old.fiscal_code, old.email_address, old.phone, old.birth_date);

        INSERT INTO members_fts(rowid, first_name, last_name, fiscal_code, email_address, phone, birth_date)
        VALUES (new.id, new.first_name, new.last_name, new.fiscal_code, new.email_address, new.phone, new.birth_date);
      END;
    SQL

    execute "INSERT INTO members_fts(members_fts) VALUES('rebuild');"
  end

  def down
    execute "DROP TRIGGER IF EXISTS members_ai"
    execute "DROP TRIGGER IF EXISTS members_ad"
    execute "DROP TRIGGER IF EXISTS members_au"
    execute "DROP TABLE IF EXISTS members_fts"
  end
end
