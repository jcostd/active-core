# Configurazione letta da Puma. I metodi usati qui fanno parte del DSL di Puma:
# https://puma.io/puma/Puma/DSL.html
#
# Puma avvia N processi (worker); ognuno serve le richieste
# con i thread di un pool interno.
#
# Il numero di worker si imposta con ENV["WEB_CONCURRENCY"] (default 1).
# Serve solo per 2 o più worker; `auto` ne avvia uno per processore.
#
# Il numero ideale di thread dipende da quanto l'app attende l'IO
# e da quanto si preferisce il throughput alla latenza.
#
# Più thread = più traffico gestito, ma per il GVL di CRuby
# il guadagno cala e la latenza peggiora.
#
# Default 3 thread: buon compromesso per una tipica app Rails.
#
# I pool di connessioni devono avere almeno tante connessioni quanti thread
# (incluso `pool` di Active Record in `database.yml`).
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Porta di ascolto di Puma (default 3000).
port ENV.fetch("PORT", 3000)

# Permette il riavvio con `bin/rails restart`.
plugin :tmp_restart

# Solid Queue gira dentro Puma (deploy su un solo server).
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]

# Litestream solo in produzione.
plugin :litestream if ENV.fetch("RAILS_ENV", "production") == "production"

# File PID: in sviluppo tmp/pids/server.pid,
# negli altri ambienti solo se richiesto.
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
