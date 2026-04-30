module FiltersHelper
  def humanize_filter_key(key)
    case key.to_s
    when "product_id" then "Corso"
    when "state"      then "Stato"
    when "query"      then "Ricerca"
    when "med_cert"   then "Certificato Medico"
    else key.to_s.humanize
    end
  end

  def humanize_filter_value(key, value)
    case key.to_s
    when "product_id"
      Product.find_by(id: value)&.name || "Sconosciuto"
    when "state"
      value.to_s == "kept" ? "Attivi" : "Archiviati"
    else
      value.to_s
    end
  end

  def state_filters
    [
      [ "Attivi", "kept" ],
      [ "Archiviati", "discarded" ]
    ]
  end

  def filtered_results_counter(pagy)
    return unless filtering?

    testo = "Trovati #{pagy.count} risultati"

    content_tag :div, testo, class: "mb-4 text-sm font-medium text-base-content/70"
  end
end
