# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create test admin user
if User.where(email: 'admin@example.com').none?
  User.create!(
    email: 'admin@example.com',
    password: 'password123',
    password_confirmation: 'password123',
    role: 'admin',
    company_name: 'Admin Company'
  )
  puts "Created admin user: admin@example.com / password123"
end

# Create test carrier
if Carrier.where(company_name: 'Test Carrier GmbH').none?
  Carrier.create!(
    company_name: 'Test Carrier GmbH',
    contact_email: 'carrier@example.com',
    contact_phone: '+49 123 456789',
    language: 'de',
    country: 'DE',
    address: 'Berlin, Germany',
    pickup_radius_km: 200,
    has_transporter: true,
    has_lkw: true,
    lkw_length_cm: 600,
    lkw_width_cm: 240,
    lkw_height_cm: 250,
    has_liftgate: true,
    has_pallet_jack: true,
    pickup_countries: ['DE', 'AT', 'CH'],
    delivery_countries: ['DE', 'AT', 'CH', 'FR', 'IT']
  )
  puts "Created test carrier"
end
