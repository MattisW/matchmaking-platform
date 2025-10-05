class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Use devise layout for Devise controllers
  layout :layout_by_resource

  # Permit additional parameters for Devise
  before_action :configure_permitted_parameters, if: :devise_controller?

  private

  def layout_by_resource
    if devise_controller?
      "devise"
    else
      "application"
    end
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:company_name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:company_name])
  end
end
