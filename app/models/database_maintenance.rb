# manutenzione dei database SQLite, lanciata da config/recurring.yml: ripara da sola o fallisce
module DatabaseMaintenance
  extend self

  class Problem < StandardError; end

  # statistiche fresche per scegliere gli indici (principale, cache, coda, cable)
  def optimize
    each_pool { |connection| connection.execute("PRAGMA optimize") }
  end

  # la ricerca dei soci si ricostruisce dalla tabella: ripara l'indice se i trigger sono mancati
  def rebuild_search
    Member.connection.execute("INSERT INTO members_fts(members_fts) VALUES('rebuild')")
    Member.connection.execute("INSERT INTO members_fts(members_fts) VALUES('optimize')")
  end

  def check
    problems = each_pool do |connection, name|
      integrity = connection.select_values("PRAGMA quick_check")
      orphans = connection.select_rows("PRAGMA foreign_key_check").map(&:first).tally

      [ ("#{name}: #{integrity.join(", ")}" unless integrity == [ "ok" ]),
        *orphans.map { |table, count| "#{name}: #{count} righe di #{table} puntano a record che non esistono" } ]
    end.flatten.compact

    raise Problem, problems.join("; ") if problems.any?
  end

  # un backup che non si è mai ripristinato non è un backup
  def verify_backup
    Litestream.verify!(ActiveRecord::Base.connection_db_config.database)
  end

  # cache e coda si riempiono e svuotano di continuo; il principale no: Litestream dovrebbe ricaricarlo tutto
  def vacuum_support_databases
    each_pool(except: ActiveRecord::Base.connection_pool) { |connection| connection.execute("VACUUM") }
  end

  private
    def each_pool(except: nil, &)
      pools = [ ActiveRecord::Base, SolidCache::Record, SolidQueue::Record, SolidCable::Record ].map(&:connection_pool).uniq - [ except ]
      pools.map { |pool| pool.with_connection { yield it, pool.db_config.name } }
    end
end
