class Members::SalesController < MembersController
  before_action :require_admin
  before_action :set_member

  def index
    @query = @member.sales
               .apply_filters(filter_params)
               .includes(:product, :user, subscription: [ :product, :sales ])

    @pagy, @sales = pagy(@query)
    @total_amount_cents = @query.sum(:amount_cents)
  end

  private
    def set_member
      @member = Member.find(params[:member_id])
    end

    def filter_params
      params.permit(:query, :sort, :product_id, :payment_method, :state)
    end
end
