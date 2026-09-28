module NavigationHelper
  # link dei menu, evidenziato (menu-active) sulla pagina corrente
  def active_link_to(name = nil, path = nil, **options, &block)
    path = name if block
    options[:class] = class_names(options[:class], "menu-active": current_page?(path))

    block ? link_to(path, options, &block) : link_to(name, path, options)
  end

  # sottomenu di una scheda nella sidebar: [ etichetta, path, icona ], le voci nil si saltano
  def record_tabs(title, *tabs)
    tag.ul class: "menu w-full" do
      tag.li(title, class: "menu-title") +
        safe_join(tabs.compact.map { |label, path, icon_name| tag.li(active_link_to(path) { icon(icon_name) + " " + label }) })
    end
  end

  # la pagina corrente in un altro mese (nil: quello in corso), con gli stessi filtri e dalla prima pagina
  def month_path(month)
    query = request.query_parameters.except("page", "month").merge(month: month&.strftime("%Y-%m")).compact
    [ request.path, query.to_query.presence ].compact.join("?")
  end
end
