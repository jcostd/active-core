class Members::SalesController < ApplicationController
  before_action :require_admin
  before_action :set_member

  def index
    query = @member.sales.kept.includes(:product, :user).order(sold_on: :desc, created_at: :desc)
    @pagy, @sales = pagy(query)
  end

  private
    def set_member
      @member = Member.find(params[:member_id])
    end
end
