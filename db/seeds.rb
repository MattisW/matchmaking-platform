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
    pickup_countries: [ 'DE', 'AT', 'CH' ],
    delivery_countries: [ 'DE', 'AT', 'CH', 'FR', 'IT' ]
  )
  puts "Created test carrier"
end

# Create package type presets
package_presets = [
  {
    name: 'Europalette',
    category: 'pallet',
    default_length_cm: 120,
    default_width_cm: 80,
    default_height_cm: 144,
    default_weight_kg: 300
  },
  {
    name: 'Halbpalette',
    category: 'pallet',
    default_length_cm: 80,
    default_width_cm: 60,
    default_height_cm: 128,
    default_weight_kg: 30
  },
  {
    name: 'Viertelpalette',
    category: 'pallet',
    default_length_cm: 60,
    default_width_cm: 40,
    default_height_cm: 100,
    default_weight_kg: 15
  },
  {
    name: 'Cartonage',
    category: 'box',
    default_length_cm: 60,
    default_width_cm: 40,
    default_height_cm: 40,
    default_weight_kg: 10
  },
  {
    name: 'Custom Package',
    category: 'custom',
    default_length_cm: nil,
    default_width_cm: nil,
    default_height_cm: nil,
    default_weight_kg: nil
  }
]

package_presets.each do |preset|
  PackageTypePreset.find_or_create_by!(name: preset[:name]) do |p|
    p.category = preset[:category]
    p.default_length_cm = preset[:default_length_cm]
    p.default_width_cm = preset[:default_width_cm]
    p.default_height_cm = preset[:default_height_cm]
    p.default_weight_kg = preset[:default_weight_kg]
  end
end
puts "Created #{package_presets.count} package type presets"

# Create pricing rules for common vehicle types
# Note: Vehicle types must match PricingRule::VEHICLE_TYPES
pricing_rules = [
  {
    vehicle_type: 'transporter',
    rate_per_km: 1.20,
    minimum_price: 80.00,
    weekend_surcharge_percent: 15.0,
    express_surcharge_percent: 25.0
  },
  {
    vehicle_type: 'sprinter',
    rate_per_km: 1.00,
    minimum_price: 70.00,
    weekend_surcharge_percent: 15.0,
    express_surcharge_percent: 25.0
  },
  {
    vehicle_type: 'lkw_7_5t',
    rate_per_km: 1.80,
    minimum_price: 150.00,
    weekend_surcharge_percent: 20.0,
    express_surcharge_percent: 30.0
  },
  {
    vehicle_type: 'lkw_12t',
    rate_per_km: 2.20,
    minimum_price: 200.00,
    weekend_surcharge_percent: 20.0,
    express_surcharge_percent: 30.0
  },
  {
    vehicle_type: 'lkw_18t',
    rate_per_km: 2.50,
    minimum_price: 250.00,
    weekend_surcharge_percent: 25.0,
    express_surcharge_percent: 35.0
  },
  {
    vehicle_type: 'lkw_24t',
    rate_per_km: 2.80,
    minimum_price: 300.00,
    weekend_surcharge_percent: 25.0,
    express_surcharge_percent: 35.0
  }
]

pricing_rules.each do |rule|
  PricingRule.find_or_create_by!(vehicle_type: rule[:vehicle_type]) do |pr|
    pr.rate_per_km = rule[:rate_per_km]
    pr.minimum_price = rule[:minimum_price]
    pr.weekend_surcharge_percent = rule[:weekend_surcharge_percent]
    pr.express_surcharge_percent = rule[:express_surcharge_percent]
    pr.active = true
  end
end
puts "Created #{pricing_rules.count} pricing rules"
