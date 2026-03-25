class FeedbacksController < ApplicationController
  def new
    @feedback = Feedback.new
    @feedback.page_url = params[:current_page] || request.referer
    render layout: "modal"
  end

  def create
    @feedback = current_user.feedbacks.build(feedback_params)

    @feedback.browser_info = request.user_agent

    if @feedback.save
      redirect_back fallback_location: root_path, notice: "Segnalazione inviata. Grazie per il tuo aiuto!"
    else
      render :new, layout: "modal", status: :unprocessable_entity
    end
  end

  private
    def feedback_params
      params.require(:feedback).permit(:message, :page_url)
    end
end
