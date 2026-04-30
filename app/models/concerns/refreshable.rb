module Refreshable
  extend ActiveSupport::Concern

  included do
    broadcasts_refreshes
    broadcasts_refreshes_to ->(record) { record.class.model_name.plural }
  end
end
