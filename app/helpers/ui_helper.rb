module UiHelper
  def ui_avatar(record, size: "size-14", text_size: "text-lg")
    tag.div class: "avatar avatar-placeholder" do
      tag.div tag.span(record.initials, class: [ "font-bold font-mono uppercase", text_size ]), class: [ "rounded-box shadow-sm", size ], style: record.avatar_color_style
    end
  end

  BADGE_TONES = { ghost: "badge-ghost", info: "badge-info", success: "badge-success", error: "badge-error" }.freeze

  def ui_badge(text, tone: :ghost)
    tag.span text, class: [ "badge badge-sm uppercase text-[10px] font-bold", BADGE_TONES.fetch(tone) ]
  end

  # azioni nell'intestazione di una scheda: sul telefono solo l'icona
  def header_button(label, path, icon_name, tone: "btn-ghost", **options)
    link_to path, class: [ "btn btn-sm", tone ], title: label, **options do
      icon(icon_name) + tag.span(label, class: "hidden sm:inline")
    end
  end

  def header_archive_button(label, path, confirm:)
    header_button label, path, "delete", tone: "btn-ghost text-error", data: { turbo_method: :delete, turbo_confirm: confirm }
  end

  # figura di una riga senza avatar
  def row_icon(name) = tag.div(icon(name), class: "size-10 bg-base-200 rounded-box grid place-items-center text-base-content/50")

  def ui_row_edit_button(path, title: "Modifica")
    link_to icon("edit"), path, class: "btn btn-square btn-ghost text-base-content/50 hover:text-primary", title:, data: { turbo_frame: "modal" }
  end

  def ui_row_delete_button(path, confirm: "Sei sicuro?", title: "Archivia")
    link_to icon("delete"), path, class: "btn btn-square btn-ghost text-base-content/50 hover:text-error hover:bg-error/10", title:,
                                  data: { turbo_method: :delete, turbo_confirm: confirm }
  end

  def ui_requirement_badge(condition, text:, icon_name:, active_class: "badge-info badge-soft")
    if condition
      tag.div icon(icon_name, classes: "size-3") + " #{text}", class: [ "badge badge-sm gap-1 font-bold", active_class ], title: "Richiede #{text}"
    else
      tag.div "No #{text}", class: "badge badge-sm badge-ghost opacity-40 font-normal line-through", title: "Non richiede #{text}"
    end
  end

  def ui_status_badge(is_valid, valid_text:, invalid_text:, icon_name: nil, invalid_tone: "badge-error")
    tag.div class: [ "badge badge-sm badge-soft gap-1 font-bold", is_valid ? "badge-success" : invalid_tone ], title: ("Attenzione: #{invalid_text}" unless is_valid) do
      is_valid ? safe_join([ (icon(icon_name, classes: "size-3") if icon_name), valid_text ], " ") : icon("error", classes: "size-3") + " #{invalid_text}"
    end
  end
end
