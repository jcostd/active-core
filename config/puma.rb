# thread per processo: le connessioni del database devono essere almeno altrettante (database.yml)
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

port ENV.fetch("PORT", 3000)

plugin :tmp_restart
# Solid Queue dentro Puma: un solo server
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]
plugin :litestream if ENV.fetch("RAILS_ENV", "production") == "production"

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
