class Quote < ApplicationRecord
  # Quote statuses
  STATUSES = %w[pending accepted declined expired].freeze

  # Associations
  belongs_to :transport_request
  has_many :quote_line_items, dependent: :destroy, inverse_of: :quote

  # Validations
  validates :transport_request_id, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :total_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :base_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :surcharge_total, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :currency, presence: true

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :accepted, -> { where(status: 'accepted') }
  scope :declined, -> { where(status: 'declined') }
  scope :expired, -> { where(status: 'expired') }

  # Accept the quote
  def accept!
    return false if status != 'pending'

    transaction do
      update!(status: 'accepted', accepted_at: Time.current)
      transport_request.update!(status: 'quote_accepted')
    end
  end

  # Decline the quote
  def decline!
    return false if status != 'pending'

    transaction do
      update!(status: 'declined', declined_at: Time.current)
      transport_request.update!(status: 'quote_declined')
    end
  end

  # Check if quote is expired
  def expired?
    valid_until.present? && valid_until < Time.current
  end

  # Check if quote is still pending
  def pending?
    status == 'pending'
  end

  # Check if quote is accepted
  def accepted?
    status == 'accepted'
  end

  # Check if quote is declined
  def declined?
    status == 'declined'
  end

  # Check if quote can be modified
  def can_be_modified?
    pending?
  end

  # Formatted total price
  def formatted_total_price
    "#{total_price.round(2)} #{currency}"
  end

  # Status badge color for UI
  def status_badge_class
    case status
    when 'pending'
      'bg-yellow-100 text-yellow-800'
    when 'accepted'
      'bg-green-100 text-green-800'
    when 'declined'
      'bg-red-100 text-red-800'
    when 'expired'
      'bg-gray-100 text-gray-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end
end
