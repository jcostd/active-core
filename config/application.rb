require_relative "boot"

require "rails"

# niente action_text, action_mailbox, active_storage e action_mailer
%w[
  active_record/railtie
  action_controller/railtie
  action_view/railtie
  active_job/railtie
  action_cable/engine
  rails/test_unit/railtie
].each { require it }

Bundler.require(*Rails.groups)

module ActiveCore
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])

    config.time_zone = "Rome"

    # solo italiano: le ASD sono un istituto giuridico italiano
    config.i18n.available_locales = [ :it ]
    config.i18n.default_locale    = :it
  end
end
