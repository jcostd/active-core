module AccessLogsHelper
  def access_log_status_color(status)
    case status.to_sym
    when :ok then "success"
    when :warning then "warning"
    when :error then "error"
    else "base-content"
    end
  end

  def access_log_status_icon(status)
    case status.to_sym
    when :ok then "success"
    when :warning then "warning"
    when :error then "error"
    else "help"
    end
  end

  def access_log_status_label(status)
    case status.to_sym
    when :ok then "Consentito"
    when :warning then "Avviso"
    when :error then "Negato"
    else "Sconosciuto"
    end
  end

  def access_log_activity_name(log)
    log.discipline&.name || "Accesso Generico"
  end
end
