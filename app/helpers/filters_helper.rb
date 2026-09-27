module FiltersHelper
  FILTER_KEYS = { "query" => "Ricerca", "month" => "Mese" }.freeze

  def state_filters
    [
      [ "Attivi", "kept" ],
      [ "Archiviati", "discarded" ]
    ]
  end

  def filtered_results_counter(pagy)
    return unless filtering?

    content_tag :div, "Trovati #{pagy.count} risultati", class: "mb-4 text-sm font-medium text-base-content/70"
  end

  # select del cassetto filtri: si invia da sola al cambio e lascia le sue etichette ai chip dei filtri attivi
  def filter_select(form, name, choices, label:, blank:)
    filter_labels[name.to_s] = { label:, values: choice_labels(choices) }

    tag.fieldset class: "fieldset" do
      tag.legend(label, class: "fieldset-legend") +
        form.select(name, choices, { include_blank: blank, selected: params[name] },
                    class: "select w-full", data: { action: "change->autosubmit#submit" })
    end
  end

  def humanize_filter_key(key)
    filter_labels.dig(key.to_s, :label) || FILTER_KEYS.fetch(key.to_s) { key.to_s.humanize }
  end

  def humanize_filter_value(key, value)
    filter_labels.dig(key.to_s, :values, value.to_s) || (key.to_s == "month" ? month_label(value) : value.to_s)
  end

  private
    def filter_labels
      @filter_labels ||= {}
    end

    # anche le opzioni raggruppate: [ [ gruppo, [ [ etichetta, valore ], ... ] ], ... ]
    def choice_labels(choices)
      choices.flat_map { |label, value| value.is_a?(Array) ? value : [ [ label, value ] ] }
             .to_h { |label, value| [ value.to_s, label ] }
    end

    def month_label(value)
      l(Date.strptime(value.to_s, "%Y-%m"), format: "%B %Y").capitalize
    rescue Date::Error
      value.to_s
    end
end
