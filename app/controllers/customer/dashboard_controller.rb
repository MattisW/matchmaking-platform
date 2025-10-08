module Customer
  class DashboardController < BaseController
    def show
      @recent_requests = current_user.transport_requests.recent.limit(10)
      @active_requests = current_user.transport_requests.active
      @pending_offers_count = CarrierRequest.joins(:transport_request)
                                            .where(transport_requests: { user_id: current_user.id })
                                            .where(status: "offered")
                                            .count
    end
  end
end
