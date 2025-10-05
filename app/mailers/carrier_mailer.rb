class CarrierMailer < ApplicationMailer
  def invitation(carrier_request_id)
    @carrier_request = CarrierRequest.find(carrier_request_id)
    @carrier = @carrier_request.carrier
    @transport_request = @carrier_request.transport_request
    @offer_url = offer_url(@carrier_request)

    mail(
      to: @carrier.contact_email,
      subject: 'Neue Transportanfrage'
    )
  end

  def offer_accepted(carrier_request_id)
    @carrier_request = CarrierRequest.find(carrier_request_id)
    @carrier = @carrier_request.carrier
    @transport_request = @carrier_request.transport_request

    mail(
      to: @carrier.contact_email,
      subject: 'Ihr Angebot wurde angenommen'
    )
  end

  def offer_rejected(carrier_request_id)
    @carrier_request = CarrierRequest.find(carrier_request_id)
    @carrier = @carrier_request.carrier
    @transport_request = @carrier_request.transport_request

    mail(
      to: @carrier.contact_email,
      subject: 'Transportanfrage wurde vergeben'
    )
  end
end
