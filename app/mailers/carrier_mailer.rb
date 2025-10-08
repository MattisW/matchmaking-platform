class CarrierMailer < ApplicationMailer
  def invitation(carrier_request_id)
    @carrier_request = CarrierRequest.find(carrier_request_id)
    @carrier = @carrier_request.carrier
    @transport_request = @carrier_request.transport_request
    @offer_url = offer_url(@carrier_request)

    I18n.with_locale(@carrier.language&.to_sym || :de) do
      mail(
        to: @carrier.contact_email,
        subject: t('carrier_mailer.invitation.subject')
      )
    end
  end

  def offer_accepted(carrier_request_id)
    @carrier_request = CarrierRequest.find(carrier_request_id)
    @carrier = @carrier_request.carrier
    @transport_request = @carrier_request.transport_request

    I18n.with_locale(@carrier.language&.to_sym || :de) do
      mail(
        to: @carrier.contact_email,
        subject: t('carrier_mailer.offer_accepted.subject')
      )
    end
  end

  def offer_rejected(carrier_request_id)
    @carrier_request = CarrierRequest.find(carrier_request_id)
    @carrier = @carrier_request.carrier
    @transport_request = @carrier_request.transport_request

    I18n.with_locale(@carrier.language&.to_sym || :de) do
      mail(
        to: @carrier.contact_email,
        subject: t('carrier_mailer.offer_rejected.subject')
      )
    end
  end
end
