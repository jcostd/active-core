module UserPreferences
  extend ActiveSupport::Concern

  THEMES = %w[light dark corporate business dim].freeze

  included do
    store_accessor :preferences, :theme, :locale

    validates :theme, inclusion: { in: THEMES }, allow_blank: true
    validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }, allow_blank: true
  end

  def theme
    saved_theme = super.presence
    THEMES.include?(saved_theme) ? saved_theme : "corporate"
  end

  def locale
    super.presence || I18n.default_locale.to_s
  end
end
