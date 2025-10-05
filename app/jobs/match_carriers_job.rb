class MatchCarriersJob < ApplicationJob
  queue_as :default

  def perform(transport_request_id)
    transport_request = TransportRequest.find(transport_request_id)

    # Run the matching algorithm
    matcher = Matching::Algorithm.new(transport_request)
    match_count = matcher.run

    Rails.logger.info "Matched #{match_count} carriers for TransportRequest ##{transport_request.id}"

    # Chain the invitation job if matches were found
    if match_count > 0
      SendCarrierInvitationsJob.perform_later(transport_request_id)
    else
      # No matches found, update status
      transport_request.update(status: 'new')
    end
  end
end
