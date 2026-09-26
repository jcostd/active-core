namespace :members do
  desc "Elenca i soci attivi con codice fiscale non valido o da completare"
  task invalid_fiscal_codes: :environment do
    members = Member.kept.order(:last_name, :first_name)
    missing = members.missing_fiscal_code.to_a
    invalid = members.where.not(fiscal_code: nil).reject { FiscalCode.valid?(it.fiscal_code) }

    if missing.empty? && invalid.empty?
      puts "✅ Tutti i codici fiscali sono validi."
      next
    end

    if invalid.any?
      puts "⚠️  #{invalid.size} soci con codice fiscale non valido:"
      invalid.each { puts "  ##{it.id}  #{it.full_name.ljust(30)} #{it.fiscal_code}" }
    end

    if missing.any?
      puts "📝 #{missing.size} soci con CF da completare:"
      missing.each { puts "  ##{it.id}  #{it.full_name}" }
    end
  end
end
