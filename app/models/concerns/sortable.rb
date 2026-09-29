# ordinamenti offerti dai filtri: SORTS mappa il parametro sort all'order; la prima voce è il predefinito
module Sortable
  extend ActiveSupport::Concern

  included do
    scope :sorted_by, ->(key) { order(model::SORTS.fetch(key.to_s) { model::SORTS.values.first }) }
  end
end
