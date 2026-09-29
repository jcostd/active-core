ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Prepara le gem del Gemfile.
require "bootsnap/setup" # Avvio più veloce: mette in cache le operazioni costose.
