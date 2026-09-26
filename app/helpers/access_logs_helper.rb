module AccessLogsHelper
  # unica fonte per gli esiti degli accessi; classi scritte per intero perché Tailwind le trovi
  ACCESS_LOG_STATUS_STYLES = {
    "ok"      => { label: "Consentito", icon: "success", badge: "badge-success", tint: "bg-success/10 text-success" },
    "warning" => { label: "Avviso",     icon: "warning", badge: "badge-warning", tint: "bg-warning/10 text-warning" },
    "error"   => { label: "Negato",     icon: "error",   badge: "badge-error",   tint: "bg-error/10 text-error" }
  }.freeze

  def access_log_status_style(status)
    ACCESS_LOG_STATUS_STYLES.fetch(status.to_s)
  end

  def access_log_status_badge(log)
    style = access_log_status_style(log.status)
    tag.span class: [ "badge badge-sm badge-soft gap-1", style[:badge] ] do
      safe_join([ icon(style[:icon], classes: "size-3"), style[:label] ])
    end
  end

  def access_log_status_icon(log)
    style = access_log_status_style(log.status)
    tag.div icon(style[:icon]), class: [ "p-2 rounded-box", style[:tint] ]
  end

  def access_log_activity_name(log)
    log.discipline&.name || "Accesso Generico"
  end
end
