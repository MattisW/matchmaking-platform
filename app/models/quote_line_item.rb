class QuoteLineItem < ApplicationRecord
  # Associations
  belongs_to :quote, inverse_of: :quote_line_items

  # Validations
  validates :description, presence: true
  validates :amount, presence: true, numericality: true

  # Default scope for ordering
  default_scope -> { order(:line_order, :created_at) }

  # Formatted amount
  def formatted_amount
    "#{amount.round(2)} #{quote.currency}"
  end

  # Check if this is a surcharge (positive additional cost)
  def surcharge?
    amount > 0 && line_order > 0
  end

  # Check if this is a discount (negative amount)
  def discount?
    amount < 0
  end
end
