class Carrier < ApplicationRecord
  # Serialized arrays for SQLite compatibility
  serialize :pickup_countries, coder: JSON, type: Array
  serialize :delivery_countries, coder: JSON, type: Array

  # Associations
  has_many :carrier_requests, dependent: :destroy
  has_many :transport_requests, through: :carrier_requests

  # Geocoding
  geocoded_by :address
  after_validation :geocode, if: :address_changed?

  # Validations
  validates :company_name, presence: true
  validates :contact_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :language, inclusion: { in: %w[de en fr it nl], allow_nil: true }
  validates :pickup_radius_km, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :rating_communication, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5, allow_nil: true }
  validates :rating_punctuality, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5, allow_nil: true }

  # Scopes
  scope :active, -> { where(blacklisted: [false, nil]) }
  scope :recent, -> { order(created_at: :desc) }
  scope :with_transporter, -> { where(has_transporter: true) }
  scope :with_lkw, -> { where(has_lkw: true) }
end
