module Product::Filterable
  extend ActiveSupport::Concern

  SORTS = {
    "created_desc" => { created_at: :desc },
    "created_asc"  => { created_at: :asc },
    "name_asc"     => { name: :asc },
    "name_desc"    => { name: :desc }
  }.freeze

  included do
    include Sortable

    scope :search_text, ->(query) { where("products.name LIKE ?", "%#{sanitize_sql_like(query)}%") if query.present? }
    scope :with_accounting_category, ->(category) { where(accounting_category: category) if category.in?(accounting_categories.keys) }
  end

  class_methods do
    def apply_filters(params = {})
      kept.search_text(params[:query]).with_accounting_category(params[:accounting_category]).sorted_by(params[:sort])
    end
  end
end
