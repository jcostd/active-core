class Kiosk::BaseController < ApplicationController
  layout "kiosk"

  private
    def kiosk_request? = true
end
