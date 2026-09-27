module Sale::Filterable
  extend ActiveSupport::Concern

  SORTS = {
    "sold_desc"    => { sold_on: :desc, created_at: :desc },
    "created_desc" => { created_at: :desc },
    "created_asc"  => { created_at: :asc },
    "name_asc"     => { product_name_snapshot: :asc },
    "name_desc"    => { product_name_snapshot: :desc }
  }.freeze

  PERIODS = {
    "today"      => -> { Date.current..Date.current },
    "this_month" => -> { Date.current.all_month },
    "last_month" => -> { Date.current.last_month.all_month },
    "this_year"  => -> { Date.current.all_year }
  }.freeze

  included do
    include Sortable

    scope :search_text, ->(query) {
      next if query.blank?

      joins(:member).where("CAST(sales.receipt_number AS TEXT) LIKE :q OR members.first_name LIKE :q " \
                           "OR members.last_name LIKE :q OR sales.product_name_snapshot LIKE :q",
                           q: "%#{sanitize_sql_like(query)}%")
    }

    scope :by_payment_method,      ->(method)  { where(payment_method: method) if method.in?(payment_methods.keys) }
    scope :by_product,             ->(id)      { where(product_id: id) if id.present? }
    scope :by_period,              ->(period)  { where(sold_on: PERIODS[period].call) if PERIODS.key?(period) }
    scope :by_operator,            ->(user_id) { where(user_id:) if user_id.present? }
    scope :by_accounting_category, ->(category) { where(receipt_sequence: category) if category.present? }
  end

  class_methods do
    def apply_filters(params = {})
      (params[:state] == "discarded" ? discarded : kept)
        .search_text(params[:query])
        .by_payment_method(params[:payment_method])
        .by_product(params[:product_id])
        .by_period(params[:period])
        .by_accounting_category(params[:accounting_category])
        .by_operator(params[:operator_id])
        .sorted_by(params[:sort])
    end
  end
end
