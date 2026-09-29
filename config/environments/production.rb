require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  # gli asset hanno il digest nel nome: cache lunghissima
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # in LAN su HTTP: niente force_ssl né assume_ssl
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)
  # con "debug" si logga tutto, anche dati personali
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/up"
  config.active_support.report_deprecations = false

  config.cache_store = :solid_cache_store
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [ :id ]

  # protezione DNS rebinding: APP_HOSTS="palestra.lan,192.168.1.10"
  if (hosts = ENV["APP_HOSTS"].to_s.split(",").map(&:strip).compact_blank).any?
    config.hosts = hosts
    config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
  end
end
