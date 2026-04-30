class ApplicationController < ActionController::Base
  include Themable, Localizable, Authentication

  include Pagy::Method

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
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
