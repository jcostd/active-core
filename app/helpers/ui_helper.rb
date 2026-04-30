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

  def ui_row_edit_button(path, title: "Modifica")
    link_to path,
            class: "btn btn-square btn-ghost text-base-content/50 hover:text-primary",
            data: { turbo_frame: "modal" },
            title: title do
      icon("edit")
    end
  end

  def ui_row_delete_button(path, confirm: "Sei sicuro?", title: "Archivia")
    link_to path,
            class: "btn btn-square btn-ghost text-base-content/50 hover:text-error hover:bg-error/10",
            title: title,
            data: {
              turbo_method: :delete,
              turbo_confirm: confirm
            } do
      icon("delete")
    end
  end

  def ui_requirement_badge(condition, text:, icon_name:, active_class: "badge-info badge-soft")
    if condition
      content_tag(:div, class: "badge badge-sm gap-1 font-bold #{active_class}", title: "Richiede #{text}") do
        icon(icon_name, classes: "size-3") + " #{text}"
      end
    else
      content_tag(:div, class: "badge badge-sm badge-ghost opacity-40 gap-1 font-normal line-through", title: "Non richiede #{text}") do
        "No #{text}"
      end
    end
  end

  def ui_status_badge(is_valid, valid_text:, invalid_text:, valid_class: "badge-success badge-soft", invalid_class: "badge-error badge-soft", icon_name: nil)
    base_classes = "badge badge-sm gap-1 font-bold"

    if is_valid
      content_tag(:div, class: "#{base_classes} #{valid_class}") do
        (icon_name ? icon(icon_name, classes: "size-3") + " " : "".html_safe) + valid_text
      end
    else
      content_tag(:div, class: "#{base_classes} #{invalid_class}", title: "Attenzione: #{invalid_text}") do
        icon("error", classes: "size-3") + " #{invalid_text}"
      end
    end
  end
end
