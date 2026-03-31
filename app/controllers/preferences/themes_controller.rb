class Preferences::ThemesController < ApplicationController
  def update
    current_user.update(theme: params.require(:theme))

    redirect_back_or_to root_path
  end
end
