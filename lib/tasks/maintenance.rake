namespace :maintenance do
  desc "Bonifica i temi legacy degli utenti, forzando il fallback a 'corporate'"
  task sanitize_themes: :environment do
    puts "🕵️‍♂️ Ricerca di utenti con temi fuori menu (non-Omakase)..."

    invalid_users = User.where.not("preferences->>'theme' IN (?)", UserPreferences::THEMES)
                      .where.not("preferences->>'theme' IS NULL")

    count = invalid_users.count

    if count.zero?
      puts "✅ Tutto pulito! Nessun tema legacy trovato nel database."
      next
    end

    puts "🧹 Trovati #{count} utenti da bonificare. Inizio pulizia..."

    invalid_users.find_each do |user|
      new_preferences = user.preferences.merge("theme" => "corporate")

      user.update_column(:preferences, new_preferences)

      print "."
    end

    puts "\n🎉 Bonifica completata! #{count} profili aggiornati a 'corporate'."
  end
end
