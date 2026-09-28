namespace :fts do
  desc "Ricostruisce l'indice di ricerca dei soci (FTS5)"
  task rebuild: :environment do
    DatabaseMaintenance.rebuild_search
    puts "✅ FTS ricostruito"
  end
end
