# Database Schema

**Last Updated:** 2025-10-08
**Schema Version:** 2025_10_08_075819
**Related Docs:** [Project Architecture](./project_architecture.md), [Adding Migrations SOP](../SOP/adding_database_migrations.md)

---

## Overview

The database uses **SQLite 3.x** for all environments (development, test, production). The schema supports a logistics matchmaking platform with users, carriers, transport requests, quotes, and pricing.

**Key Characteristics:**
- **17 migrations** applied
- **10 tables** total
- **7 foreign key constraints**
- **Serialized JSON arrays** for multi-value fields (SQLite limitation)
- **Decimal precision** for money and measurements

---

## Entity Relationship Diagram

```
users (1) ──── (N) transport_requests
                      │
                      ├── (1) quote ──── (N) quote_line_items
                      │
                      ├── (N) carrier_requests ──── (N) carriers
                      │
                      └── (N) package_items

pricing_rules (standalone reference table)
package_type_presets (standalone reference table)

carriers (N) ──── (N) carrier_requests ──── (N) transport_requests
```

---

## Core Tables

### 1. users (Devise Authentication)

**Purpose:** Authenticated users with role-based access (admin, dispatcher, customer)

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | integer | PK | Auto-increment primary key |
| `email` | string | NOT NULL, unique, indexed | Login email |
| `encrypted_password` | string | NOT NULL | Devise password hash |
| `reset_password_token` | string | unique, indexed | Password reset token |
| `reset_password_sent_at` | datetime | | Reset token timestamp |
| `remember_created_at` | datetime | | Remember me timestamp |
| `role` | string | NOT NULL, default: 'dispatcher' | User role: admin, dispatcher, customer |
| `company_name` | string | | Company/organization name |
| `theme_mode` | string | NOT NULL, default: 'light' | UI theme: light, dark, system |
| `accent_color` | string | NOT NULL, default: '#3B82F6' | UI accent color (hex) |
| `font_size` | string | NOT NULL, default: 'medium' | UI font size |
| `density` | string | NOT NULL, default: 'comfortable' | UI density: comfortable, compact |
| `avatar_url` | string | | Profile picture URL |
| `locale` | string | NOT NULL, default: 'de' | Preferred language: de, en |
| `created_at` | datetime | NOT NULL | Record creation |
| `updated_at` | datetime | NOT NULL | Last update |

**Indexes:**
- `index_users_on_email` (unique)
- `index_users_on_reset_password_token` (unique)

**Relationships:**
- `has_many :transport_requests`

**Roles:**
- `admin`: Full platform access
- `dispatcher`: Same as admin (legacy)
- `customer`: Own transport requests only

**Model:** `app/models/user.rb`

---

### 2. carriers (No Authentication)

**Purpose:** Logistics carriers/transporters (NOT users, no login)

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | integer | PK | Auto-increment primary key |
| `company_name` | string | | Carrier company name |
| `contact_email` | string | | Primary contact email |
| `contact_phone` | string | | Phone number |
| `preferred_contact_method` | string | | Email or phone preference |
| `language` | string | | Preferred language (de, en) |
| `country` | string | | Base country code |
| `address` | text | | Full address for geocoding |
| `latitude` | decimal | | Geocoded latitude |
| `longitude` | decimal | | Geocoded longitude |
| `pickup_radius_km` | integer | | Service radius in km |
| `ignore_radius` | boolean | | Override radius restrictions |
| `has_transporter` | boolean | | Has small van/transporter |
| `has_lkw` | boolean | | Has truck (LKW) |
| `lkw_length_cm` | integer | | Truck cargo length |
| `lkw_width_cm` | integer | | Truck cargo width |
| `lkw_height_cm` | integer | | Truck cargo height |
| `has_liftgate` | boolean | | Hydraulic liftgate available |
| `has_pallet_jack` | boolean | | Pallet jack available |
| `has_gps_tracking` | boolean | | GPS tracking capability |
| `blacklisted` | boolean | | Excluded from matching |
| `rating_communication` | decimal | | Communication rating (1-5) |
| `rating_punctuality` | decimal | | Punctuality rating (1-5) |
| `notes` | text | | Internal admin notes |
| `pickup_countries` | text | | JSON array of country codes |
| `delivery_countries` | text | | JSON array of country codes |
| `created_at` | datetime | NOT NULL | Record creation |
| `updated_at` | datetime | NOT NULL | Last update |

**Serialized Fields:**
```ruby
# In model
serialize :pickup_countries, coder: JSON, type: Array
serialize :delivery_countries, coder: JSON, type: Array

# Example values
pickup_countries: ["DE", "AT", "CH"]
delivery_countries: ["DE", "AT", "CH", "FR", "IT"]
```

**Indexes:**
- ⚠️ **Missing:** Index on `country` (filtering)
- ⚠️ **Missing:** Index on `blacklisted` (filtering)

**Relationships:**
- `has_many :carrier_requests`
- `has_many :transport_requests, through: :carrier_requests`

**Geocoding:**
- Uses Geocoder gem to set lat/lon from address
- Callback: `after_validation :geocode, if: :address_changed?`

**Model:** `app/models/carrier.rb`

---

### 3. transport_requests (Main Entity)

**Purpose:** Shipping requests from customers

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | integer | PK | Auto-increment primary key |
| `user_id` | integer | FK, NOT NULL, indexed | Customer who created request |
| `status` | string | | Workflow status (see enums below) |
| **Pickup Address** ||||
| `start_country` | string | | Pickup country code |
| `start_address` | text | | Full pickup address |
| `start_latitude` | decimal | | Geocoded pickup latitude |
| `start_longitude` | decimal | | Geocoded pickup longitude |
| `start_company_name` | string | | Pickup company name |
| `start_street` | string | | Pickup street |
| `start_street_number` | string | | Pickup street number |
| `start_city` | string | | Pickup city |
| `start_state` | string | | Pickup state/region |
| `start_postal_code` | string | | Pickup postal code |
| `start_notes` | text | | Pickup location notes |
| **Delivery Address** ||||
| `destination_country` | string | | Delivery country code |
| `destination_address` | text | | Full delivery address |
| `destination_latitude` | decimal | | Geocoded delivery latitude |
| `destination_longitude` | decimal | | Geocoded delivery longitude |
| `destination_company_name` | string | | Delivery company name |
| `destination_street` | string | | Delivery street |
| `destination_street_number` | string | | Delivery street number |
| `destination_city` | string | | Delivery city |
| `destination_state` | string | | Delivery state/region |
| `destination_postal_code` | string | | Delivery postal code |
| `destination_notes` | text | | Delivery location notes |
| **Route** ||||
| `distance_km` | integer | | Calculated distance |
| **Timing** ||||
| `pickup_date_from` | datetime | | Pickup window start |
| `pickup_date_to` | datetime | | Pickup window end |
| `pickup_time_from` | string | | Pickup time start (HH:MM) |
| `pickup_time_to` | string | | Pickup time end (HH:MM) |
| `pickup_notes` | text | | Pickup timing notes |
| `delivery_date_from` | datetime | | Delivery window start |
| `delivery_date_to` | datetime | | Delivery window end |
| `delivery_time_from` | string | | Delivery time start (HH:MM) |
| `delivery_time_to` | string | | Delivery time end (HH:MM) |
| `delivery_notes` | text | | Delivery timing notes |
| **Cargo (Legacy)** ||||
| `vehicle_type` | string | | transporter, lkw, either |
| `cargo_length_cm` | integer | | Legacy cargo length |
| `cargo_width_cm` | integer | | Legacy cargo width |
| `cargo_height_cm` | integer | | Legacy cargo height |
| `cargo_weight_kg` | integer | | Legacy cargo weight |
| **Cargo (New System)** ||||
| `shipping_mode` | string | default: 'packages' | packages, loading_meters, vehicle_booking |
| `loading_meters` | decimal | | Required loading meters (max 13.6) |
| `total_height_cm` | integer | | Total height for loading meters |
| `total_weight_kg` | decimal | | Total weight |
| **Requirements** ||||
| `requires_liftgate` | boolean | | Liftgate required |
| `requires_pallet_jack` | boolean | | Pallet jack required |
| `requires_side_loading` | boolean | | Side loading required |
| `requires_tarp` | boolean | | Tarp covering required |
| `requires_gps_tracking` | boolean | | GPS tracking required |
| `driver_language` | string | | Required driver language |
| **Matching** ||||
| `matchmaking_status` | string | | Legacy matching status |
| `matched_carrier_id` | integer | FK, indexed | Winning carrier (if accepted) |
| **Timestamps** ||||
| `created_at` | datetime | NOT NULL | Record creation |
| `updated_at` | datetime | NOT NULL | Last update |

**Status Enum:**
- `new` - Just created, no quote yet
- `quoted` - Quote generated
- `quote_accepted` - Customer accepted quote
- `quote_declined` - Customer declined quote
- `matching` - Finding carriers
- `matched` - Carrier selected
- `in_transit` - Shipment in progress
- `delivered` - Completed
- `cancelled` - Cancelled by customer

**Shipping Mode Enum:**
- `packages` - Individual package items (uses package_items table)
- `loading_meters` - Specified loading meters (uses loading_meters field)
- `vehicle_booking` - Book entire vehicle (uses vehicle_type field)

**Indexes:**
- `index_transport_requests_on_user_id`
- `index_transport_requests_on_matched_carrier_id`
- ⚠️ **Missing:** Index on `status` (filtering)

**Relationships:**
- `belongs_to :user`
- `belongs_to :matched_carrier, class_name: "Carrier", optional: true`
- `has_many :carrier_requests`
- `has_many :carriers, through: :carrier_requests`
- `has_many :package_items`
- `has_one :quote`

**Model:** `app/models/transport_request.rb`

---

### 4. carrier_requests (Join Table + Offers)

**Purpose:** Links carriers to transport requests, stores offer details

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | integer | PK | Auto-increment primary key |
| `transport_request_id` | integer | FK, NOT NULL, indexed | Transport request |
| `carrier_id` | integer | FK, NOT NULL, indexed | Carrier |
| `status` | string | | new, sent, offered, rejected, won |
| `distance_to_pickup_km` | decimal | | Calculated distance to pickup |
| `distance_to_delivery_km` | decimal | | Calculated distance to delivery |
| `in_radius` | boolean | | Within carrier's service radius |
| `email_sent_at` | datetime | | When invitation was sent |
| `response_date` | datetime | | When carrier responded |
| `offered_price` | decimal | | Carrier's price quote |
| `offered_delivery_date` | datetime | | Carrier's delivery date |
| `transport_type` | string | | Carrier's transport method |
| `vehicle_type` | string | | Vehicle carrier will use |
| `driver_language` | string | | Driver's language |
| `notes` | text | | Carrier's offer notes |
| `created_at` | datetime | NOT NULL | Record creation |
| `updated_at` | datetime | NOT NULL | Last update |

**Status Flow:**
1. `new` - Created by matching algorithm
2. `sent` - Invitation email sent
3. `offered` - Carrier submitted offer
4. `won` - Customer accepted offer
5. `rejected` - Customer rejected offer

**Indexes:**
- `index_carrier_requests_on_carrier_id`
- `index_carrier_requests_on_transport_request_id`
- ⚠️ **Missing:** Index on `status` (filtering)
- ⚠️ **Missing:** Composite index on `[transport_request_id, status]`

**Relationships:**
- `belongs_to :transport_request`
- `belongs_to :carrier`

**Model:** `app/models/carrier_request.rb`

---

### 5. quotes

**Purpose:** Automated price quotes for transport requests

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | integer | PK | Auto-increment primary key |
| `transport_request_id` | integer | FK, NOT NULL, indexed | Transport request |
| `status` | string | NOT NULL, default: 'pending', indexed | pending, accepted, declined, expired |
| `total_price` | decimal(10,2) | NOT NULL | Final quote price |
| `base_price` | decimal(10,2) | NOT NULL | Base transport cost |
| `surcharge_total` | decimal(10,2) | default: 0.0 | Sum of all surcharges |
| `currency` | string | NOT NULL, default: 'EUR' | Currency code |
| `valid_until` | datetime | | Quote expiration |
| `accepted_at` | datetime | | When customer accepted |
| `declined_at` | datetime | | When customer declined |
| `notes` | text | | Additional quote notes |
| `created_at` | datetime | NOT NULL | Record creation |
| `updated_at` | datetime | NOT NULL | Last update |

**Status Flow:**
1. `pending` - Awaiting customer decision
2. `accepted` - Customer accepted → triggers matching
3. `declined` - Customer declined
4. `expired` - Past valid_until date

**Calculation:**
```
total_price = base_price + surcharge_total
base_price = max(distance_km × rate_per_km, minimum_price)
surcharges = weekend_surcharge + express_surcharge
```

**Indexes:**
- `index_quotes_on_transport_request_id`
- `index_quotes_on_status`

**Relationships:**
- `belongs_to :transport_request`
- `has_many :quote_line_items, inverse_of: :quote`

**Validations:**
- One quote per transport_request (uniqueness)
- Status must be in enum
- Prices >= 0

**Model:** `app/models/quote.rb`

---

### 6. quote_line_items

**Purpose:** Itemized breakdown of quote costs

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | integer | PK | Auto-increment primary key |
| `quote_id` | integer | FK, NOT NULL, indexed | Parent quote |
| `description` | string | NOT NULL | Line item description |
| `calculation` | string | | Formula/explanation |
| `amount` | decimal(10,2) | NOT NULL | Line item cost |
| `line_order` | integer | default: 0 | Display order (0 = base) |
| `created_at` | datetime | NOT NULL | Record creation |
| `updated_at` | datetime | NOT NULL | Last update |

**Line Order:**
- `0` = Base transport cost (always first)
- `1+` = Surcharges (weekend, express, etc.)

**Example Data:**
```
line_order: 0
description: "Base Transport Cost"
calculation: "585 km × €1.50/km"
amount: 877.50

line_order: 1
description: "Weekend Surcharge"
calculation: "20% surcharge"
amount: 175.50
```

**Indexes:**
- `index_quote_line_items_on_quote_id`
- `index_quote_line_items_on_quote_id_and_line_order`

**Relationships:**
- `belongs_to :quote, inverse_of: :quote_line_items`

**Default Scope:**
```ruby
default_scope -> { order(:line_order, :created_at) }
```

**Model:** `app/models/quote_line_item.rb`

---

### 7. pricing_rules

**Purpose:** Configurable pricing per vehicle type

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | integer | PK | Auto-increment primary key |
| `vehicle_type` | string | NOT NULL, indexed | Vehicle category |
| `rate_per_km` | decimal(10,2) | NOT NULL | Base rate per kilometer |
| `minimum_price` | decimal(10,2) | NOT NULL | Minimum charge |
| `weekend_surcharge_percent` | decimal(5,2) | default: 0.0 | Saturday/Sunday % |
| `express_surcharge_percent` | decimal(5,2) | default: 0.0 | <24hr delivery % |
| `active` | boolean | NOT NULL, default: true, indexed | Enabled/disabled |
| `created_at` | datetime | NOT NULL | Record creation |
| `updated_at` | datetime | NOT NULL | Last update |

**Vehicle Types:**
- `transporter` - Small van
- `sprinter` - Sprinter van
- `lkw_7_5t` - 7.5 ton truck
- `lkw_12t` - 12 ton truck
- (extensible - add more as needed)

**Calculation Logic:**
```ruby
base = max(distance_km * rate_per_km, minimum_price)

if weekend_pickup?
  weekend_surcharge = base * (weekend_surcharge_percent / 100)
end

if express_delivery?  # <24 hours
  express_surcharge = base * (express_surcharge_percent / 100)
end

total = base + weekend_surcharge + express_surcharge
```

**Indexes:**
- `index_pricing_rules_on_vehicle_type`
- `index_pricing_rules_on_active`

**Scopes:**
```ruby
scope :active, -> { where(active: true) }
scope :for_vehicle_type, ->(type) { active.where(vehicle_type: type).first }
```

**Model:** `app/models/pricing_rule.rb`

---

### 8. package_items

**Purpose:** Individual packages for transport requests (shipping_mode = 'packages')

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | integer | PK | Auto-increment primary key |
| `transport_request_id` | integer | FK, NOT NULL, indexed | Parent transport request |
| `package_type` | string | NOT NULL | Type of package |
| `quantity` | integer | default: 1 | Number of this package |
| `length_cm` | integer | | Package length |
| `width_cm` | integer | | Package width |
| `height_cm` | integer | | Package height |
| `weight_kg` | decimal(10,2) | | Package weight |
| `created_at` | datetime | NOT NULL | Record creation |
| `updated_at` | datetime | NOT NULL | Last update |

**Package Types:**
- `euro_pallet` - Standard EUR pallet (120×80×144cm)
- `industrial_pallet` - Industrial pallet (120×100×144cm)
- `half_pallet` - Half pallet (60×80×144cm)
- `box` - Custom box
- `crate` - Wooden crate

**Indexes:**
- `index_package_items_on_transport_request_id`
- `index_package_items_on_transport_request_id_and_package_type`

**Relationships:**
- `belongs_to :transport_request`

**Nested Attributes:**
```ruby
# In TransportRequest model
accepts_nested_attributes_for :package_items,
                              allow_destroy: true,
                              reject_if: :all_blank
```

**Model:** `app/models/package_item.rb`

---

### 9. package_type_presets

**Purpose:** Default dimensions for package types (reference data)

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | integer | PK | Auto-increment primary key |
| `name` | string | NOT NULL, unique, indexed | Preset name |
| `category` | string | | Preset category (pallets, boxes, etc.) |
| `default_length_cm` | integer | | Default length |
| `default_width_cm` | integer | | Default width |
| `default_height_cm` | integer | | Default height |
| `default_weight_kg` | decimal(10,2) | | Default weight |
| `created_at` | datetime | NOT NULL | Record creation |
| `updated_at` | datetime | NOT NULL | Last update |

**Seed Data:**
```ruby
PackageTypePreset.create!([
  { name: 'Euro Pallet', category: 'pallets',
    default_length_cm: 120, default_width_cm: 80,
    default_height_cm: 144, default_weight_kg: 500 },
  { name: 'Industrial Pallet', category: 'pallets',
    default_length_cm: 120, default_width_cm: 100,
    default_height_cm: 144, default_weight_kg: 700 },
  # ... more presets
])
```

**Indexes:**
- `index_package_type_presets_on_name` (unique)

**Usage:**
- Auto-fill package dimensions when type is selected
- JavaScript reads presets, populates form fields

**Model:** `app/models/package_type_preset.rb`

---

## Relationships Map

### One-to-Many (1:N)

```
User (1) ──── (N) TransportRequest
TransportRequest (1) ──── (N) PackageItem
TransportRequest (1) ──── (N) CarrierRequest
Carrier (1) ──── (N) CarrierRequest
Quote (1) ──── (N) QuoteLineItem
```

### One-to-One (1:1)

```
TransportRequest (1) ──── (1) Quote
```

### Many-to-Many (N:N)

```
Carrier (N) ←──→ (N) TransportRequest
    (through carrier_requests join table)
```

### Optional Associations

```
TransportRequest (N) ──── (0..1) Carrier (matched_carrier)
```

---

## Foreign Keys

**Enforced Constraints:**
```sql
carrier_requests → carriers (carrier_id)
carrier_requests → transport_requests (transport_request_id)
package_items → transport_requests (transport_request_id)
quote_line_items → quotes (quote_id)
quotes → transport_requests (transport_request_id)
transport_requests → carriers (matched_carrier_id)
transport_requests → users (user_id)
```

**On Delete Cascade:**
- Quote deleted → quote_line_items deleted
- TransportRequest deleted → carrier_requests, package_items, quote deleted
- User deleted → transport_requests deleted (⚠️ **danger in production**)
- Carrier deleted → carrier_requests deleted

---

## Indexes

### Existing Indexes

**Primary Keys (auto-indexed):**
- All `id` columns

**Unique Indexes:**
- `users.email`
- `users.reset_password_token`
- `package_type_presets.name`

**Foreign Key Indexes:**
- `carrier_requests.carrier_id`
- `carrier_requests.transport_request_id`
- `package_items.transport_request_id`
- `quote_line_items.quote_id`
- `quotes.transport_request_id`
- `transport_requests.user_id`
- `transport_requests.matched_carrier_id`

**Filtering Indexes:**
- `pricing_rules.active`
- `pricing_rules.vehicle_type`
- `quotes.status`

**Composite Indexes:**
- `package_items.[transport_request_id, package_type]`
- `quote_line_items.[quote_id, line_order]`

### Missing Indexes (Performance Opportunities)

⚠️ **Should Add:**

```ruby
# transport_requests
add_index :transport_requests, :status
add_index :transport_requests, [:user_id, :status]

# carrier_requests
add_index :carrier_requests, :status
add_index :carrier_requests, [:transport_request_id, :status]
add_index :carrier_requests, :in_radius

# carriers
add_index :carriers, :country
add_index :carriers, :blacklisted
add_index :carriers, [:blacklisted, :country]
```

**Rationale:**
- `status` fields frequently filtered in queries
- Composite indexes for common WHERE clauses
- `blacklisted` always checked in matching algorithm

---

## Serialized Fields (SQLite Workaround)

### Why Serialization?

SQLite doesn't support native array or JSONB types. We store arrays as JSON-encoded text.

### Implementation

**Migration:**
```ruby
add_column :carriers, :pickup_countries, :text
add_column :carriers, :delivery_countries, :text
```

**Model:**
```ruby
class Carrier < ApplicationRecord
  serialize :pickup_countries, coder: JSON, type: Array
  serialize :delivery_countries, coder: JSON, type: Array
end
```

**Usage:**
```ruby
carrier = Carrier.create!(
  pickup_countries: ['DE', 'AT', 'CH'],
  delivery_countries: ['DE', 'AT', 'CH', 'FR', 'IT']
)

carrier.pickup_countries
# => ["DE", "AT", "CH"]

carrier.pickup_countries.include?('DE')
# => true
```

**Database Storage:**
```sql
-- Stored as JSON text
pickup_countries: '["DE","AT","CH"]'
```

**Limitations:**
- Can't query array elements with SQL (must load record)
- Can't use database array functions
- Migrations to PostgreSQL will need conversion

---

## Status Enums

### TransportRequest Status

| Status | Description | Next States |
|--------|-------------|-------------|
| `new` | Just created | quoted, cancelled |
| `quoted` | Quote generated | quote_accepted, quote_declined |
| `quote_accepted` | Customer accepted | matching |
| `quote_declined` | Customer declined | cancelled |
| `matching` | Finding carriers | matched |
| `matched` | Carrier selected | in_transit |
| `in_transit` | Shipment in progress | delivered |
| `delivered` | Completed | (final) |
| `cancelled` | Cancelled | (final) |

### Quote Status

| Status | Description | Actions |
|--------|-------------|---------|
| `pending` | Awaiting decision | Accept, Decline |
| `accepted` | Accepted | Triggers matching |
| `declined` | Declined | (final) |
| `expired` | Past valid_until | (final) |

### CarrierRequest Status

| Status | Description | Next States |
|--------|-------------|-------------|
| `new` | Created by matching | sent |
| `sent` | Email invitation sent | offered |
| `offered` | Carrier submitted offer | won, rejected |
| `won` | Customer accepted | (final) |
| `rejected` | Customer rejected | (final) |

---

## Data Integrity Rules

### Validations (Model Level)

**User:**
- Email: present, unique, valid format (Devise)
- Role: present, in ['admin', 'dispatcher', 'customer']
- Locale: in ['de', 'en']

**TransportRequest:**
- start_address: present
- destination_address: present
- pickup_date_from: present
- delivery_date_from: after pickup_date_from
- shipping_mode: in ['packages', 'loading_meters', 'vehicle_booking']
- loading_meters: 0-13.6 (if shipping_mode = loading_meters)

**Quote:**
- transport_request_id: present, unique
- status: in ['pending', 'accepted', 'declined', 'expired']
- total_price: >= 0
- base_price: >= 0

**QuoteLineItem:**
- description: present
- amount: numeric

**PackageItem:**
- package_type: present
- quantity: >= 1

### Cascade Deletes

**Configured:**
- TransportRequest deleted → package_items, carrier_requests, quote deleted
- Quote deleted → quote_line_items deleted
- Carrier deleted → carrier_requests deleted (⚠️ orphans transport_requests)

**Missing Protection:**
- User deletion should be soft-delete or prevented if has transport_requests
- Carrier deletion should check for active carrier_requests

---

## Performance Optimization Plan

### Query Optimization

**N+1 Queries to Fix:**
```ruby
# Bad (N+1)
TransportRequest.all.each { |tr| tr.user.email }

# Good (eager load)
TransportRequest.includes(:user).all.each { |tr| tr.user.email }
```

**Common Includes Needed:**
```ruby
# Admin transport requests index
TransportRequest.includes(:user, :matched_carrier)

# Carrier requests with offers
CarrierRequest.includes(:carrier, :transport_request)

# Quotes with line items
Quote.includes(:quote_line_items)
```

### Index Additions (Priority Order)

1. **High Priority:**
   ```ruby
   add_index :transport_requests, :status
   add_index :carrier_requests, :status
   add_index :carriers, :blacklisted
   ```

2. **Medium Priority:**
   ```ruby
   add_index :transport_requests, [:user_id, :status]
   add_index :carrier_requests, [:transport_request_id, :status]
   ```

3. **Low Priority:**
   ```ruby
   add_index :carriers, :country
   add_index :carrier_requests, :in_radius
   ```

### Counter Caches (Future)

```ruby
# On User for transport_requests count
add_column :users, :transport_requests_count, :integer, default: 0

# On TransportRequest for carrier_requests count
add_column :transport_requests, :carrier_requests_count, :integer, default: 0
```

---

## Migration History

| Version | Date | Description |
|---------|------|-------------|
| 20251005145817 | 2025-10-05 | Devise create users |
| 20251005145822 | 2025-10-05 | Add role to users |
| 20251005145843 | 2025-10-05 | Create carriers |
| 20251005145851 | 2025-10-05 | Create transport requests |
| 20251005145858 | 2025-10-05 | Create carrier requests |
| 20251005145903 | 2025-10-05 | Add country arrays to carriers |
| 20251005183351 | 2025-10-05 | Fix matched carrier foreign key |
| 20251005184929 | 2025-10-05 | Make matched carrier id nullable |
| 20251006073502 | 2025-10-06 | Add detailed address fields to transport requests |
| 20251006090509 | 2025-10-06 | Add shipping mode to transport requests |
| 20251006090518 | 2025-10-06 | Create package items |
| 20251006090527 | 2025-10-06 | Create package type presets |
| 20251006123021 | 2025-10-06 | Add theme preferences to users |
| 20251008072221 | 2025-10-08 | Add locale to users |
| 20251008075725 | 2025-10-08 | Create pricing rules |
| 20251008075752 | 2025-10-08 | Create quotes |
| 20251008075819 | 2025-10-08 | Create quote line items |

---

## Related Documentation

- **[Project Architecture](./project_architecture.md)** - System overview
- **[Adding Migrations SOP](../SOP/adding_database_migrations.md)** - How to modify schema
- **[Performance Optimization](../Tasks/performance_optimization.md)** - Index & query improvements
- **[Quote System SOP](../SOP/quote_system_implementation.md)** - Quote/pricing implementation

---

**Schema File:** `db/schema.rb`
**Current Version:** 2025_10_08_075819
**Last Review:** 2025-10-08
**Next Review Due:** 2025-11-08
