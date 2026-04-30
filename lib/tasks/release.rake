namespace :release do
  desc "Esegue tutte le migrazioni dati e le bonifiche per il lancio della Versione 1"
  task v1: :environment do
    puts "🚀 Inizio procedura di roll-out per la Versione 1.0..."

    puts "\n▶ Step 1: Ricostruzione indici Full-Text (FTS5)"
    Rake::Task["fts:rebuild"].invoke

    puts "\n▶ Step 2: Bonifica temi utente legacy"
    Rake::Task["maintenance:sanitize_themes"].invoke

    puts "\n✅ Rilascio V1 completato con successo. Sistema pronto!"
  end
end
