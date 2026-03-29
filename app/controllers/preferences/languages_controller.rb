class Preferences::LanguagesController < ApplicationController
  def update
    if current_user.update(locale: params.require(:language))
      I18n.locale = current_user.locale
    end

    redirect_back(fallback_location: root_path)
  end
end
