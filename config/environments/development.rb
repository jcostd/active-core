require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Le impostazioni qui hanno la precedenza su config/application.rb.

  # Le modifiche al codice sono subito attive senza riavviare il server.
  config.enable_reloading = true

  # Nessun caricamento anticipato del codice all'avvio.
  config.eager_load = false

  # Mostra i report d'errore completi.
  config.consider_all_requests_local = true

  # Attiva Server-Timing.
  config.server_timing = true

  # Attiva/disattiva la cache di Action Controller (disattivata di default).
  # Usare rails dev:cache per cambiarla.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true
    config.public_file_server.headers = { "cache-control" => "public, max-age=#{2.days.to_i}" }
  else
    config.action_controller.perform_caching = false
  end

  # Con :null_store nessuna cache.
  config.cache_store = :memory_store

  # Deprecazioni nel log di Rails.
  config.active_support.deprecation = :log

  # Errore al caricamento pagina se ci sono migrazioni pendenti.
  config.active_record.migration_error = :page_load

  # Nei log evidenzia il codice che ha generato le query.
  config.active_record.verbose_query_logs = true

  # Aggiunge tag di contesto alle query SQL nei log.
  config.active_record.query_log_tags_enabled = true

  # Nei log evidenzia il codice che ha accodato i job.
  config.active_job.verbose_enqueue_logs = true

  # Nei log evidenzia il codice che ha fatto il redirect.
  config.action_dispatch.verbose_redirect_logs = true

  # Nessun log per le richieste degli asset.
  config.assets.quiet = true

  # Errore sulle traduzioni mancanti.
  # config.i18n.raise_on_missing_translations = true

  # Annota le viste renderizzate con il nome del file.
  config.action_view.annotate_rendered_view_with_filenames = true

  # Decommentare per accettare Action Cable da qualsiasi origine.
  # config.action_cable.disable_request_forgery_protection = true

  # Errore se only/except di un before_action citano azioni inesistenti.
  config.action_controller.raise_on_missing_callback_actions = true

  # Autocorrezione RuboCop sui file creati da `bin/rails generate`.
  # config.generators.apply_rubocop_autocorrect_after_generate!
end
