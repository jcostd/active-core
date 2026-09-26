source "https://rubygems.org"

# Per Rails edge: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.2"
gem "rails-i18n", "~> 8.1"

# Bloccata sotto la 3.0: json 3.x accetta solo argomenti keyword in JSON.parse
# e rompe ActiveSupport::JSON.decode di activesupport 8.1.3.1.
gem "json", "< 3"

# Asset pipeline di Rails [https://github.com/rails/propshaft]
gem "propshaft"
# SQLite come database di Active Record
gem "sqlite3", ">= 2.1"
# Web server Puma [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# JavaScript con import map ESM [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Navigazione rapida stile SPA di Hotwire [https://turbo.hotwired.dev]
gem "turbo-rails"
# Framework JavaScript leggero di Hotwire [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"

# has_secure_password di Active Model [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows non ha i fusi orari: serve la gem tzinfo-data
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Adapter su database per Rails.cache, Active Job e Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

gem "phonelib", "~> 0.10.15"
gem "pagy", "~> 43.2"

gem "prawn", "~> 2.4"
gem "prawn-table", "~> 0.2.2"

gem "litestream", "~> 0.14.0"

# Avvio più veloce grazie alla cache; richiesta in config/boot.rb
gem "bootsnap", require: false

# Deploy come container Docker [https://kamal-deploy.org]
gem "kamal", require: false

# Cache/compressione HTTP degli asset e X-Sendfile per Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Varianti di Active Storage [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

group :development, :test do
  # Vedi https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Controlla le gem per vulnerabilità note (eccezioni in config/bundler-audit.yml)
  gem "bundler-audit", require: false

  # Analisi statica di sicurezza [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Stile Ruby Omakase [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Console nelle pagine d'errore [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Test di sistema [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end
