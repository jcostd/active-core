module Filterable
  extend ActiveSupport::Concern

  included do
    helper_method :filtering?
  end

  private
    def filtering?
      filter_params.to_h.except(:sort).reject { |_, v| v.blank? }.any?
    end

    def filter_params
      params.permit(:query, :sort, :state)
    end
end
