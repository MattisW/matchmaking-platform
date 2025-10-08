class DashboardController < ApplicationController
  layout "admin"
  before_action :authenticate_user!
  before_action :ensure_admin!

  def index
    @total_requests = TransportRequest.count
    @active_requests = TransportRequest.active.count
    @total_carriers = Carrier.active.count
    @pending_offers = CarrierRequest.where(status: "offered").count
    @recent_requests = TransportRequest.includes(:user).recent.limit(10)
  end
end
