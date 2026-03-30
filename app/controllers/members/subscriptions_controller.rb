class Members::SubscriptionsController < ApplicationController
  before_action :set_member

  def index
    query = @member.subscriptions.kept.includes(:product, :sale).order(end_date: :desc)
    @pagy, @subscriptions = pagy(query)
  end

  private
    def set_member
      @member = Member.find(params[:member_id])
    end
end
