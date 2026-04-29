class Disciplines::MembersController < ApplicationController
  include Filterable

  before_action :set_discipline

  def index
    @products = @discipline.products.kept

    @query = @discipline.recent_subscriptions
               .apply_filters(filter_params)
               .includes(:product, member: [:subscriptions])
               .references(:subscriptions)

    @pagy, @subscriptions = pagy(@query)
  end

  private
    def set_discipline
      @discipline = Discipline.find(params[:discipline_id])
    end

    def filter_params
      params.permit(:query, :sort, :state, :product_id, :membership_status, :med_cert)
    end
end
