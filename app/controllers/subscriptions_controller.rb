class SubscriptionsController < ApplicationController
  before_action :require_admin, only: %i[ edit update ]
  before_action :set_subscription, only: [ :edit, :update, :destroy ]

  layout "modal", only: [ :edit, :update ]


  def index
    @subscriptions = Subscription.kept.includes(:member, :product)

    if params[:filter] == "expiring"
      @subscriptions = @subscriptions.expiring.order(:end_date)
    else
      @subscriptions = @subscriptions.order(created_at: :desc)
    end

    @pagy, @subscriptions = pagy(@subscriptions)
  end

  def edit; end

  def update
    if @subscription.update(subscription_params)
      redirect_to [ @subscription.member, :subscriptions ], notice: "Abbonamento aggiornato con successo."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    unless @subscription.discardable_by?(current_user)
      return redirect_back(fallback_location: @subscription.member, status: :see_other, alert: "Questo abbonamento non è più annullabile.")
    end

    @subscription.discard!
    redirect_back(fallback_location: @subscription.member, status: :see_other, notice: "Abbonamento e pagamenti collegati annullati.")
  end

  private
    def set_subscription
      @subscription = Subscription.find(params[:id])
    end

    def subscription_params
      params.expect(subscription: %i[ start_date end_date entry_limit ])
    end
end
