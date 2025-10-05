class OffersController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

  def show
    @carrier_request = CarrierRequest.find(params[:id])
    @transport_request = @carrier_request.transport_request
    @carrier = @carrier_request.carrier
  end

  def submit_offer
    @carrier_request = CarrierRequest.find(params[:id])

    if @carrier_request.update(offer_params)
      @carrier_request.update(
        status: 'offered',
        response_date: Time.current
      )
      redirect_to offer_path(@carrier_request), notice: 'Ihr Angebot wurde erfolgreich übermittelt.'
    else
      @transport_request = @carrier_request.transport_request
      @carrier = @carrier_request.carrier
      render :show, status: :unprocessable_entity
    end
  end

  private

  def offer_params
    params.require(:carrier_request).permit(
      :offered_price,
      :offered_delivery_date,
      :transport_type,
      :vehicle_type,
      :driver_language,
      :notes
    )
  end
end
