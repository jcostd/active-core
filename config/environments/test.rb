# il database di test si svuota e si ricrea a ogni esecuzione
Rails.application.configure do
  config.enable_reloading = false
  # in locale rallenta il singolo test; in CI verifica che tutta l'app si carichi
  config.eager_load = ENV["CI"].present?

  config.public_file_server.headers = { "cache-control" => "public, max-age=3600" }
  config.consider_all_requests_local = true
  config.cache_store = :null_store
  config.action_dispatch.show_exceptions = :rescuable
  config.action_controller.allow_forgery_protection = false
  config.active_support.deprecation = :stderr
  config.i18n.raise_on_missing_translations = true
  config.action_controller.raise_on_missing_callback_actions = true
end
