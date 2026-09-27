module Themable
  extend ActiveSupport::Concern

  included do
    helper_method :current_theme
  end

  private
    def current_theme
      current_user&.theme || UserPreferences::DEFAULT_THEME
    end
end
