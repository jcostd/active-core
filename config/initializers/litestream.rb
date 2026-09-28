# backup continuo del database su un bucket S3; i segreti stanno nelle credentials cifrate
Rails.application.configure do
  litestream = Rails.application.credentials.litestream

  config.litestream.replica_bucket = litestream&.replica_bucket # l'URL del bucket senza https://
  config.litestream.replica_key_id = litestream&.replica_key_id
  config.litestream.replica_access_key = litestream&.replica_access_key
  config.litestream.replica_endpoint = litestream&.replica_endpoint # solo per servizi non AWS
  config.litestream.replica_region = "auto"
end
