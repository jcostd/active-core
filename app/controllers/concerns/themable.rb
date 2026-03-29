module Themable
  extend ActiveSupport::Concern

  included do
    before_action :set_theme
  end

  private
    def set_theme
      @theme = current_user&.theme_or_default || "light"
    end
end
