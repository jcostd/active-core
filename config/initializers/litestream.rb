# Configurazione della gem litestream-ruby.
# Ogni opzione diventa una variabile d'ambiente, es.
# config.replica_bucket diventa LITESTREAM_REPLICA_BUCKET.
# Così Litestream si configura con le credentials cifrate di Rails
# o con valori disponibili solo a runtime.

Rails.application.configure do
  # Litestream si configura via variabili d'ambiente; i segreti nelle credentials cifrate.
  litestream_credentials = Rails.application.credentials.litestream

  # Bucket della replica: URL del bucket senza `https://`.
  # Per esempio, con DigitalOcean Spaces l'URL del bucket è:
  #
  #   https://myapp.fra1.digitaloceanspaces.com
  #
  # e quindi `replica_bucket` vale:
  #
  #   myapp.fra1.digitaloceanspaces.com
  #
  config.litestream.replica_bucket = litestream_credentials&.replica_bucket
  #
  # Chiave di accesso al bucket della replica.
  config.litestream.replica_key_id = litestream_credentials&.replica_key_id
  #
  # Chiave segreta del bucket della replica.
  config.litestream.replica_access_key = litestream_credentials&.replica_access_key
  #
  # Regione del bucket (solo AWS S3 e Backblaze B2).
  config.litestream.replica_region = "auto"
  #
  # Endpoint del servizio compatibile S3 (solo per servizi non AWS).
  config.litestream.replica_endpoint = litestream_credentials&.replica_endpoint

  # Percorso del file di configurazione di Litestream
  # config.config_path = Rails.root.join("config", "litestream.yml")

  # Dashboard di Litestream
  #
  # Controller base della dashboard
  # config.litestream.base_controller_class = "MyApplicationController"
  #
  # Credenziali di accesso alla dashboard
  # config.litestream.username = litestream_credentials&.username
  # config.litestream.password = litestream_credentials&.password
end
