module Customer
  class CarrierRequestsController < BaseController
    before_action :set_transport_request
    before_action :set_carrier_request, only: [ :accept, :reject ]

    def index
      @carrier_requests = @transport_request.carrier_requests
                                             .includes(:carrier)
                                             .where(status: [ "offered", "won", "rejected" ])
                                             .order(offered_price: :asc)
    end

    def accept
      ActiveRecord::Base.transaction do
        @carrier_request.update!(status: "won")

        # Reject all other offers
        @transport_request.carrier_requests
                          .where.not(id: @carrier_request.id)
                          .where(status: "offered")
                          .update_all(status: "rejected")

        # Update transport request
        @transport_request.update!(
          status: "matched",
          matched_carrier_id: @carrier_request.carrier_id
        )

        # Send notification emails
        CarrierMailer.offer_accepted(@carrier_request.id).deliver_later

        @transport_request.carrier_requests
                          .where(status: "rejected")
                          .each do |cr|
          CarrierMailer.offer_rejected(cr.id).deliver_later
        end
      end

      redirect_to customer_transport_request_path(@transport_request),
                  notice: "Offer accepted! Carrier has been notified."
    end

    def reject
      @carrier_request.update(status: "rejected")
      CarrierMailer.offer_rejected(@carrier_request.id).deliver_later

      redirect_to customer_transport_request_path(@transport_request),
                  notice: "Offer rejected."
    end

    private

    def set_transport_request
      @transport_request = current_user.transport_requests.find(params[:transport_request_id])
    end

    def set_carrier_request
      @carrier_request = @transport_request.carrier_requests.find(params[:id])
    end
  end
end
