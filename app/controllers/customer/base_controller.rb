module Customer
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_customer!
    layout "customer"

    private

    def ensure_customer!
      unless current_user.customer?
        redirect_to root_path, alert: "Access denied. This area is for customers only."
      end
    end
  end
end
