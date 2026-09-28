# L'ambiente di test serve solo a eseguire la suite di test.
# Il database di test è uno spazio temporaneo: viene svuotato
# e ricreato a ogni esecuzione. Non affidarsi ai dati che contiene!

Rails.application.configure do
  # Le impostazioni qui hanno la precedenza su config/application.rb.

  # Durante i test i file non sono osservati: niente ricaricamento.
  config.enable_reloading = false

  # Il caricamento anticipato carica tutta l'app: in locale rallenta il singolo test,
  # in CI invece va attivato per verificare che funzioni prima del deploy.
  config.eager_load = ENV["CI"].present?

  # File pubblici con cache-control per velocizzare i test.
  config.public_file_server.headers = { "cache-control" => "public, max-age=3600" }

  # Mostra i report d'errore completi.
  config.consider_all_requests_local = true
  config.cache_store = :null_store

  # Pagine d'errore per le eccezioni gestibili, rilancia le altre.
  config.action_dispatch.show_exceptions = :rescuable

  # Protezione CSRF disattivata nei test.
  config.action_controller.allow_forgery_protection = false

  # Deprecazioni su stderr.
  config.active_support.deprecation = :stderr

  # Errore sulle traduzioni mancanti.
  config.i18n.raise_on_missing_translations = true

  # Annota le viste renderizzate con il nome del file.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Errore se only/except di un before_action citano azioni inesistenti.
  config.action_controller.raise_on_missing_callback_actions = true
end
