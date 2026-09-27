module UserPreferences
  extend ActiveSupport::Concern

  THEMES = %w[light dark corporate business dim].freeze
  DEFAULT_THEME = "corporate"

  included do
    store_accessor :preferences, :theme

    validates :theme, inclusion: { in: THEMES }, allow_blank: true

    def theme
      super.presence || DEFAULT_THEME
    end
  end
end
