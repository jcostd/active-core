module NavigationHelper
  # link dei menu, evidenziato (menu-active) sulla pagina corrente
  def active_link_to(name = nil, path = nil, **options, &block)
    path = name if block
    options[:class] = class_names(options[:class], "menu-active": current_page?(path))

    block ? link_to(path, options, &block) : link_to(name, path, options)
  end
end
