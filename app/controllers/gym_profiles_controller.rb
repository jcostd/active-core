class GymProfilesController < ApplicationController
  before_action :require_admin
  before_action :set_gym_profile

  layout "modal"

  def edit; end

  def update
    if @gym_profile.update(gym_profile_params)
      turbo_refresh_or_redirect_to edit_gym_profile_path, notice: "Dati dell'ASD aggiornati."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_gym_profile
      @gym_profile = GymProfile.current
    end

    def gym_profile_params
      params.expect(gym_profile: %i[ name vat_number address_line_1 address_line_2 zip_code city phone email bank_iban ])
    end
end
