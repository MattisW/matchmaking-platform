class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_many :transport_requests, dependent: :destroy

  # Validations
  validates :role, inclusion: { in: %w[admin dispatcher customer] }
  validates :company_name, presence: true
  validates :locale, inclusion: { in: %w[de en] }, allow_nil: false

  # Callbacks
  after_initialize :set_default_locale, if: :new_record?

  # Role helper methods
  def admin?
    role == "admin"
  end

  def dispatcher?
    role == "dispatcher"
  end

  def customer?
    role == "customer"
  end

  def admin_or_dispatcher?
    admin? || dispatcher?
  end

  private

  def set_default_locale
    self.locale ||= 'de'
  end
end
