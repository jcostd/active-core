namespace :fts do
  desc "Ricostruisce gli indici di ricerca Full-Text (FTS5) in SQLite"
  task rebuild: :environment do
    puts "🔄 Ricostruzione dell'indice FTS per i Membri in corso..."

    start_time = Time.current

    ActiveRecord::Base.connection.execute("INSERT INTO members_fts(members_fts) VALUES('rebuild');")

    elapsed = Time.current - start_time

    puts "✅ FTS ricostruito con successo in #{elapsed.round(2)} secondi!"
  end
end
