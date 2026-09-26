require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Le impostazioni qui hanno la precedenza su config/application.rb.

  # Il codice non viene ricaricato tra una richiesta e l'altra.
  config.enable_reloading = false

  # Carica tutto il codice all'avvio: più veloce e meno memoria (ignorato dai task Rake).
  config.eager_load = true

  # Report d'errore completi disattivati.
  config.consider_all_requests_local = false

  # Attiva la cache dei frammenti nelle viste.
  config.action_controller.perform_caching = true

  # Cache lunghissima per gli asset: hanno tutti il digest nel nome.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Servire immagini, CSS e JS da un asset server esterno.
  # config.asset_host = "http://assets.example.com"

  # File caricati salvati sul disco locale (opzioni in config/storage.yml).
  config.active_storage.service = :local

  # Tutto il traffico passa da un reverse proxy che termina SSL.
  # config.assume_ssl = true

  # Forza SSL, Strict-Transport-Security e cookie secure.
  # config.force_ssl = true

  # Nessun redirect a https per l'health check.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log su STDOUT con l'id della richiesta come tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Con "debug" si logga tutto (anche possibili dati personali!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Evita che gli health check intasino i log.
  config.silence_healthcheck_path = "/up"

  # Nessun log delle deprecazioni.
  config.active_support.report_deprecations = false

  # Cache persistente (Solid Cache) al posto di quella in memoria.
  config.cache_store = :solid_cache_store

  # Coda persistente (Solid Queue) per Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Ignora indirizzi email errati e non sollevare errori di invio.
  # Mettere true e configurare il server email per vedere gli errori di invio.
  # config.action_mailer.raise_delivery_errors = false

  # Host usato nei link delle email.
  # deploy in LAN su http: APP_HOST è il nome/IP che lo staff digita nel browser
  config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST", "localhost"), protocol: "http" }

  # Nessun dump dello schema dopo le migrazioni.
  config.active_record.dump_schema_after_migration = false

  # In produzione inspect mostra solo :id.
  config.active_record.attributes_for_inspect = [ :id ]

  # protezione DNS rebinding: APP_HOSTS="palestra.lan,192.168.1.10"
  if (hosts = ENV["APP_HOSTS"].to_s.split(",").map(&:strip).compact_blank).any?
    config.hosts = hosts
    config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
  end
end
