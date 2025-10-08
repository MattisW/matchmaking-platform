class CarrierRequest < ApplicationRecord
  # Associations
  belongs_to :transport_request
  belongs_to :carrier

  # Validations
  validates :status, inclusion: { in: %w[new sent offered rejected won], allow_nil: true }
  validates :carrier_id, uniqueness: { scope: :transport_request_id, message: "already matched to this request" }

  # Scopes
  scope :pending, -> { where(status: [ "new", "sent" ]) }
  scope :offered, -> { where(status: "offered") }
  scope :won, -> { where(status: "won") }
  scope :with_offers, -> { where(status: "offered").order(offered_price: :asc) }
end
