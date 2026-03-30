module IconsHelper
  def icon(name, classes: "size-5", **options)
    filename = Rails.root.join("app/assets/images/icons/#{name}.svg")

    unless File.exist?(filename)
      return content_tag(:span, name.to_s.first.upcase,
                         class: "inline-flex items-center justify-center bg-base-300 rounded text-[10px] font-bold select-none #{classes}")
    end

    svg_content = Rails.cache.fetch([ "icon_svg_fast", name, File.mtime(filename) ]) do
      File.read(filename)
    end

    doc = svg_content.dup

    if classes.present?
      if doc.include?('class="')
        doc.sub!('class="', "class=\"#{classes} ")
      else
        doc.sub!("<svg", "<svg class=\"#{classes}\"")
      end
    end

    if options.any?
      attrs = options.map { |k, v| "#{k.to_s.dasherize}=\"#{v}\"" }.join(" ")
      doc.sub!("<svg", "<svg #{attrs}")
    end

    doc.html_safe
  end
end
