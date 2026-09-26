require_relative "boot"

require "rails"

# niente action_text e action_mailbox
%w[
  active_record/railtie
  active_storage/engine
  action_controller/railtie
  action_view/railtie
  action_mailer/railtie
  active_job/railtie
  action_cable/engine
  rails/test_unit/railtie
].each { require it }

# Carica le gem del Gemfile, comprese quelle
# limitate a :test, :development o :production.
Bundler.require(*Rails.groups)

module ActiveCore
  class Application < Rails::Application
    # Default di configurazione della versione di Rails.
    config.load_defaults 8.1

    # Aggiungere a `ignore` le sottocartelle di `lib` senza file `.rb`
    # o da non ricaricare/caricare in anticipo
    # (es. `templates`, `generators`, `middleware`).
    config.autoload_lib(ignore: %w[assets tasks])

    # Configurazione di applicazione, engine e railtie.
    #
    # Si può sovrascrivere per ambiente nei file
    # di config/environments, letti dopo.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    config.time_zone = "Rome"

    # solo italiano: le ASD sono un istituto giuridico italiano
    config.i18n.available_locales = [ :it ]
    config.i18n.default_locale    = :it
  end
end
