class ApplicationController < ActionController::Base
  include Themable, Authentication

  include Pagy::Method

  default_form_builder ApplicationFormBuilder

  # Solo browser moderni (webp, web push, badge, import map, CSS nesting e :has).
  allow_browser versions: :modern

  # Un cambio dell'importmap invalida l'etag delle risposte HTML
  stale_when_importmap_changes

  private

    def turbo_refresh_or_redirect_to(fallback_path, options = {})
      respond_to do |format|
        format.turbo_stream do
          flash[:notice] = options[:notice] if options[:notice]
          flash[:alert] = options[:alert] if options[:alert]

          render turbo_stream: turbo_stream.refresh(request_id: nil)
        end

        format.html { redirect_to fallback_path, **options }
      end
    end
end
