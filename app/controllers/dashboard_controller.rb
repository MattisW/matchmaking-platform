class DashboardController < ApplicationController
  layout 'admin'
  before_action :authenticate_user!

  def index
    @total_requests = TransportRequest.count
    @active_requests = TransportRequest.active.count
    @total_carriers = Carrier.active.count
    @pending_offers = CarrierRequest.offered.count
    @recent_requests = TransportRequest.includes(:user).recent.limit(10)
  end
end
