module Customer
  class QuotesController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_customer!
    before_action :set_transport_request
    before_action :set_quote

    def accept
      if @quote.accept!
        # Trigger carrier matching after quote acceptance
        MatchCarriersJob.perform_later(@transport_request.id)

        redirect_to customer_transport_request_path(@transport_request),
                    notice: t('quotes.accepted')
      else
        redirect_to customer_transport_request_path(@transport_request),
                    alert: t('quotes.accept_failed')
      end
    end

    def decline
      if @quote.decline!
        redirect_to customer_transport_request_path(@transport_request),
                    notice: t('quotes.declined')
      else
        redirect_to customer_transport_request_path(@transport_request),
                    alert: t('quotes.decline_failed')
      end
    end

    private

    def set_transport_request
      @transport_request = current_user.transport_requests.find(params[:transport_request_id])
    end

    def set_quote
      @quote = @transport_request.quote
      unless @quote
        redirect_to customer_transport_request_path(@transport_request),
                    alert: t('quotes.not_found')
      end
    end

    def ensure_customer!
      unless current_user&.customer?
        redirect_to root_path, alert: t('flash.access_denied')
      end
    end
  end
end
