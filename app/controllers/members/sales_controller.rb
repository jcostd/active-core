class Members::SalesController < ApplicationController
  include Filterable

  before_action :require_admin
  before_action :set_member

  def index
    @pagy, @sales = pagy(@member.sales.apply_filters(filter_params).includes(:user, subscription: [ :product, :sales ]))
    @total_amount_cents = @member.sales.kept.sum(:amount_cents)
  end

  private
    def set_member
      @member = Member.find(params[:member_id])
    end

    def filter_params
      params.permit(:query, :sort, :product_id, :payment_method, :state)
    end
end
