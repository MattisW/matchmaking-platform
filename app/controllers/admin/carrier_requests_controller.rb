class Admin::CarrierRequestsController < ApplicationController
  layout "admin"
  before_action :authenticate_user!
  before_action :ensure_admin!
  before_action :set_carrier_request, only: [ :show, :accept, :reject ]

  def index
    @carrier_requests = CarrierRequest.includes(:carrier, :transport_request)
                                       .order(created_at: :desc)
                                       .page(params[:page])
  end

  def show
  end

  def accept
    ActiveRecord::Base.transaction do
      # Mark this offer as won
      @carrier_request.update!(status: "won")

      # Reject all other offers for this request
      @carrier_request.transport_request.carrier_requests
                      .where.not(id: @carrier_request.id)
                      .where(status: "offered")
                      .update_all(status: "rejected")

      # Update transport request
      @carrier_request.transport_request.update!(
        status: "matched",
        matched_carrier_id: @carrier_request.carrier_id
      )

      # Send emails
      CarrierMailer.offer_accepted(@carrier_request.id).deliver_later

      # Send rejection emails
      @carrier_request.transport_request.carrier_requests
                      .where(status: "rejected")
                      .each do |cr|
        CarrierMailer.offer_rejected(cr.id).deliver_later
      end
    end

    redirect_to admin_transport_request_path(@carrier_request.transport_request),
                notice: "Offer accepted successfully."
  end

  def reject
    @carrier_request.update(status: "rejected")
    CarrierMailer.offer_rejected(@carrier_request.id).deliver_later

    redirect_to admin_transport_request_path(@carrier_request.transport_request),
                notice: "Offer rejected."
  end

  private

  def set_carrier_request
    @carrier_request = CarrierRequest.find(params[:id])
  end
end
