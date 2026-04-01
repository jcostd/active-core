class Disciplines::MembersController < ApplicationController
  include Filterable

  before_action :set_discipline

  def index
    @products = @discipline.products.kept

    query = DisciplineSubscriptionsQuery.new(params, @discipline.recent_subscriptions)
    @pagy, @subscriptions = pagy(query.results)
  end

  private
    def set_discipline
      @discipline = Discipline.find(params[:discipline_id])
    end

    def filter_params
      params.permit(:query, :sort, :state, :product_id, :membership_status, :med_cert)
    end
end
