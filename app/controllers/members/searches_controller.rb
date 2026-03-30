class Members::SearchesController < ApplicationController
  layout false

  def index
    @members = params[:query].present? ? Member.search_text(params[:query]).limit(10) : Member.none

    render layout: false
  end
end
