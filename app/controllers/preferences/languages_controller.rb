class Preferences::LanguagesController < ApplicationController
  def update
    current_user.update(locale: params.require(:language))

    redirect_back_or_to root_path
  end
end
