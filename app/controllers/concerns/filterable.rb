module Filterable
  extend ActiveSupport::Concern

  included do
    helper_method :filtering?, :active_filters
  end

  private
    def filtering?
      active_filters.any?
    end

    def active_filters
      request.query_parameters.except(:sort, :commit, :page).reject { |_, v| v.blank? }
    end
end
