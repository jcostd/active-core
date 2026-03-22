class Members::SalesController < ApplicationController
  before_action :require_admin
  before_action :set_member

  def index
    @sales = @member.sales.kept
                      .includes(:product, :user)
                      .order(sold_on: :desc, created_at: :desc)
  end

  private
    def set_member
      @member = Member.find(params[:member_id])
    end
end
