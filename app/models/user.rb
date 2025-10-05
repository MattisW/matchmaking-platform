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
end
