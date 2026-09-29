# Usato dai server Rack per avviare l'applicazione.

require_relative "config/environment"

run Rails.application
Rails.application.load_server
