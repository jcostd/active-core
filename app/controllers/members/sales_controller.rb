class Members::SalesController < MembersController
  before_action :require_admin
  before_action :set_member

  def index
    base_scope = @member.sales.includes(:product, :user)
    query = SalesQuery.new(params, base_scope).results

    @pagy, @sales = pagy(query)
  end

  private
    def set_member
      @member = Member.find(params[:member_id])
    end
end
