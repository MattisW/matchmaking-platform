class TransportRequest < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :matched_carrier, class_name: 'Carrier', foreign_key: 'matched_carrier_id', optional: true
  has_many :carrier_requests, dependent: :destroy
  has_many :carriers, through: :carrier_requests

  # Validations
  validates :start_address, presence: true
  validates :destination_address, presence: true
  validates :pickup_date_from, presence: true
  validates :vehicle_type, inclusion: { in: %w[transporter lkw either], allow_nil: true }
  validates :status, inclusion: { in: %w[new matching matched in_transit delivered cancelled], allow_nil: true }
  validate :delivery_after_pickup

  # Scopes
  scope :active, -> { where.not(status: ['cancelled', 'delivered']) }
  scope :recent, -> { order(created_at: :desc) }
  scope :pending_matching, -> { where(status: 'new') }
  scope :matched, -> { where(status: 'matched') }

  private

  def delivery_after_pickup
    return unless pickup_date_from && delivery_date_from

    if delivery_date_from < pickup_date_from
      errors.add(:delivery_date_from, "must be after pickup date")
    end
  end
end
