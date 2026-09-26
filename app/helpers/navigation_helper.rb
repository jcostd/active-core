module NavigationHelper
  def active_link_to(text = nil, path = nil, **options, &block)
    # 1. Normalizziamo gli argomenti (gestione blocco vs standard)
    link_path = block_given? ? text : path

    # 2. Logica "Smart" per l'attivazione
    # - Se passi active: true/false -> vince lui
    # - Se passi active: /regex/ -> usa match sul path
    # - Altrimenti -> usa current_page? (standard rails)
    custom_active = options.delete(:active)

    is_active =
      case custom_active
      when true, false then custom_active
      when Regexp then request.path.match?(custom_active)
      else current_page?(link_path)
      end

    # 3. Uniamo le classi (DaisyUI 'menu-active')
    options[:class] = class_names(options[:class], "menu-active" => is_active)

    # 4. Rendering
    block_given? ? link_to(text, options, &block) : link_to(text, path, options)
  end
end
