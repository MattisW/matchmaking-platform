class SendCarrierInvitationsJob < ApplicationJob
  queue_as :default

  def perform(transport_request_id)
    transport_request = TransportRequest.find(transport_request_id)

    # Get all pending carrier requests for this transport request
    carrier_requests = transport_request.carrier_requests.where(status: "new")

    carrier_requests.each do |carrier_request|
      # Send invitation email
      CarrierMailer.invitation(carrier_request.id).deliver_later

      # Update carrier request status
      carrier_request.update(
        status: "sent",
        email_sent_at: Time.current
      )
    end

    Rails.logger.info "Sent #{carrier_requests.count} invitations for TransportRequest ##{transport_request.id}"
  end
end
