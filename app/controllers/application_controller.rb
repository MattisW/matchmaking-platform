class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Use role-based layouts
  layout :layout_by_resource

  # Set locale based on user preference
  before_action :set_locale

  # Permit additional parameters for Devise
  before_action :configure_permitted_parameters, if: :devise_controller?

  # Switch locale action (public)
  def switch_locale
    if current_user && params[:locale].in?(I18n.available_locales.map(&:to_s))
      current_user.update(locale: params[:locale])
      redirect_back(fallback_location: root_path, notice: t('locale.switched'))
    else
      redirect_back(fallback_location: root_path, alert: t('flash.error'))
    end
  end

  private

  def set_locale
    I18n.locale = current_user&.locale ||
                  extract_locale_from_accept_language_header ||
                  I18n.default_locale
  end

  def extract_locale_from_accept_language_header
    request.env['HTTP_ACCEPT_LANGUAGE']&.scan(/^[a-z]{2}/)&.first&.to_sym
  end

  def layout_by_resource
    if devise_controller?
      "devise"
    elsif current_user&.customer?
      "customer"
    elsif current_user&.admin_or_dispatcher?
      "admin"
    else
      "application"
    end
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :company_name, :role ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :company_name ])
  end

  # Authorization helpers
  def ensure_admin!
    unless current_user&.admin_or_dispatcher?
      redirect_to root_path, alert: "Access denied. Admin privileges required."
    end
  end

  def ensure_customer!
    unless current_user&.customer?
      redirect_to root_path, alert: "Access denied. This area is for customers only."
    end
  end
end
