module UiHelper
  def ui_avatar(record, size: "size-14", text_size: "text-lg")
    content_tag :div, class: "avatar avatar-placeholder" do
      color_style = record.respond_to?(:avatar_color_style) ? record.avatar_color_style : ""

      content_tag :div, class: [ "rounded-box shadow-sm", size ], style: color_style do
        content_tag :span, record.initials, class: [ "font-bold font-mono uppercase", text_size ]
      end
    end
  end

  def ui_badge(text, style: "ghost")
    content_tag :span, text, class: "badge badge-sm badge-#{style} uppercase text-[10px] font-bold"
  end
end
