class Members::SearchesController < ApplicationController
  layout false

  def index
    @members = params[:query].present? ? Member.kept.search_text(params[:query]).limit(10) : Member.none
  end
end
