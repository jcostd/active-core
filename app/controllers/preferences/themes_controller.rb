class Preferences::ThemesController < ApplicationController
  def update
    current_user.update(theme: params.require(:theme))

    redirect_back(fallback_location: root_path)
  end
end
