module IconsHelper
  ICONS_DIR = Rails.root.join("app/assets/images/icons")
  # cache nel processo: file piccoli e letti su ogni pagina, Solid Cache (database) costerebbe di più
  SVG_CACHE = Concurrent::Map.new

  def icon(name, classes: "size-5", **options)
    svg = icon_svg(name.to_s)
    classes = [ classes, options.delete(:class) ].compact_blank.join(" ")

    unless svg
      return content_tag(:span, name.to_s.first.upcase,
                         class: "inline-flex items-center justify-center bg-base-300 rounded text-[10px] font-bold select-none #{classes}")
    end

    attributes = options.merge(class: classes.presence).compact
                        .map { |key, value| %( #{key.to_s.dasherize}="#{ERB::Util.html_escape(value)}") }.join

    svg.sub("<svg", "<svg#{attributes}").html_safe
  end

  private
    def icon_svg(name)
      return read_icon(name) if Rails.env.development? # modifiche visibili senza riavvio

      SVG_CACHE.fetch_or_store(name) { read_icon(name) || false } || nil
    end

    def read_icon(name)
      path = ICONS_DIR.join("#{File.basename(name)}.svg")
      File.read(path).strip if File.file?(path)
    end
end
