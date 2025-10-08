# Implementing Comprehensive Unit Tests in Rails

**Last Updated:** 2025-10-08
**Author:** Claude Code
**Related Docs:**
- [Project Architecture](../System/project_architecture.md)
- [Database Schema](../System/database_schema.md)
- [Adding Database Migrations](./adding_database_migrations.md)

---

## Overview

This SOP provides a complete guide for implementing comprehensive unit tests in Rails 8 using Minitest. It covers fixture design, test organization, validation testing, and common patterns specific to this matchmaking platform.

**Use this guide when:**
- Adding tests for new models
- Retrofitting tests for existing models
- Debugging failing tests
- Creating fixtures for complex associations
- Testing nested attributes, scopes, and custom validations

**Estimated Time:** 2-4 hours per model (including fixtures and tests)

---

## Table of Contents

1. [Testing Philosophy](#testing-philosophy)
2. [Prerequisites](#prerequisites)
3. [Phase 1: Create Realistic Fixtures](#phase-1-create-realistic-fixtures)
4. [Phase 2: Write Model Unit Tests](#phase-2-write-model-unit-tests)
5. [Phase 3: Run and Debug Tests](#phase-3-run-and-debug-tests)
6. [Common Patterns](#common-patterns)
7. [Troubleshooting](#troubleshooting)
8. [Best Practices](#best-practices)

---

## Testing Philosophy

### What to Test

✅ **Do Test:**
- Model validations (presence, uniqueness, format, numericality)
- Associations (belongs_to, has_many, inverse_of)
- Scopes (active, recent, by_status)
- Custom methods (calculations, business logic)
- Callbacks (before_save, after_create)
- Database constraints (foreign keys, uniqueness)
- Nested attributes (accepts_nested_attributes_for)

❌ **Don't Test:**
- Rails framework behavior (Rails handles its own tests)
- Simple getters/setters (unnecessary)
- Third-party gem internals (trust the gems)

### Coverage Goals

- **Model tests:** 80-100% coverage of validations and business logic
- **Fixture coverage:** At least one fixture per major model state/type
- **Edge cases:** Boundary conditions, nil values, max/min values

---

## Prerequisites

### 1. Verify Test Environment

```bash
# Check Rails test environment is configured
rails db:test:prepare

# Verify test database exists
rails db:migrate RAILS_ENV=test
```

### 2. Understand the Model

Before writing tests, read:
- The model file (`app/models/your_model.rb`)
- The migration file (`db/migrate/*_create_your_models.rb`)
- Related models and associations
- Any validations or custom methods

Example:
```ruby
# app/models/package_item.rb
class PackageItem < ApplicationRecord
  belongs_to :transport_request, inverse_of: :package_items

  validates :package_type, presence: true
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :weight_kg, presence: true, numericality: { greater_than: 0 }
  validates :length_cm, :width_cm, :height_cm,
            numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  def total_weight
    (weight_kg || 0) * quantity
  end
end
```

### 3. Check Database Schema

```bash
# View schema for the table
rails db:schema:dump && cat db/schema.rb | grep -A 20 "create_table.*package_items"
```

Example output:
```ruby
create_table "package_items", force: :cascade do |t|
  t.integer "transport_request_id", null: false
  t.string "package_type", null: false
  t.integer "quantity", default: 1
  t.integer "length_cm"
  t.integer "width_cm"
  t.integer "height_cm"
  t.decimal "weight_kg", precision: 10, scale: 2
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["transport_request_id", "package_type"], name: "index_package_items_on_transport_request_id_and_package_type"
  t.index ["transport_request_id"], name: "index_package_items_on_transport_request_id"
end
```

**Key points to note:**
- `null: false` columns require values in fixtures
- `default: 1` means you must explicitly set `nil` to test presence validation
- `precision` and `scale` define decimal constraints
- Indexes indicate frequently queried columns

---

## Phase 1: Create Realistic Fixtures

### Why Fixtures Matter

Fixtures are **test data** that Rails loads before each test. Good fixtures:
- Represent realistic production data
- Cover edge cases (nil values, boundary conditions)
- Have correct foreign key references
- Are reusable across multiple tests

### Step 1.1: Identify Fixture Dependencies

Draw the dependency tree for your model:

```
PackageItem
  └── belongs_to :transport_request
       └── belongs_to :user
```

**Rule:** Create fixtures from the **top of the tree down** (User → TransportRequest → PackageItem).

### Step 1.2: Create Parent Fixtures First

#### Example: Users Fixture

**File:** `test/fixtures/users.yml`

```yaml
# Read about fixtures at https://api.rubyonrails.org/classes/ActiveRecord/FixtureSet.html

admin_user:
  email: admin@test.com
  encrypted_password: <%= Devise::Encryptor.digest(User, 'password123') %>
  role: admin
  company_name: Test Admin Company
  locale: de

customer_one:
  email: customer1@test.com
  encrypted_password: <%= Devise::Encryptor.digest(User, 'password123') %>
  role: customer
  company_name: Test Customer Company One
  locale: de

customer_two:
  email: customer2@test.com
  encrypted_password: <%= Devise::Encryptor.digest(User, 'password123') %>
  role: customer
  company_name: Test Customer Company Two
  locale: en
```

**Key Points:**
- Use **descriptive labels** (`admin_user`, not `one`)
- Use **ERB for Devise passwords** (required for authentication)
- Include **realistic data** (actual email formats, valid locales)
- Cover **different user roles** for comprehensive testing

#### Example: TransportRequest Fixture

**File:** `test/fixtures/transport_requests.yml`

```yaml
packages_mode:
  user: customer_one  # References the fixture label from users.yml
  status: new
  shipping_mode: packages
  start_country: DE
  start_address: "Berlin, Germany"
  start_latitude: 52.5200
  start_longitude: 13.4050
  destination_country: DE
  destination_address: "Munich, Germany"
  destination_latitude: 48.1351
  destination_longitude: 11.5820
  distance_km: 585
  pickup_date_from: 2025-10-10 09:00:00
  delivery_date_from: 2025-10-11 14:00:00
  requires_liftgate: true
  requires_gps_tracking: true
  driver_language: de

loading_meters_mode:
  user: customer_one
  status: new
  shipping_mode: loading_meters
  loading_meters: 13.6
  total_height_cm: 260
  total_weight_kg: 24000
  start_country: DE
  start_address: "Hamburg, Germany"
  start_latitude: 53.5511
  start_longitude: 9.9937
  destination_country: DE
  destination_address: "Frankfurt, Germany"
  destination_latitude: 50.1109
  destination_longitude: 8.6821
  distance_km: 393
  pickup_date_from: 2025-10-09 10:00:00
  delivery_date_from: 2025-10-10 15:00:00
  driver_language: de

vehicle_booking_mode:
  user: customer_two
  status: new
  shipping_mode: vehicle_booking
  vehicle_type: lkw
  start_country: DE
  start_address: "Cologne, Germany"
  start_latitude: 50.9375
  start_longitude: 6.9603
  destination_country: DE
  destination_address: "Stuttgart, Germany"
  destination_latitude: 48.7758
  destination_longitude: 9.1829
  distance_km: 362
  pickup_date_from: 2025-10-11 08:00:00
  delivery_date_from: 2025-10-12 16:00:00
  requires_gps_tracking: true
  driver_language: en

completed_request:
  user: customer_one
  status: delivered
  shipping_mode: packages
  start_country: DE
  start_address: "Leipzig, Germany"
  start_latitude: 51.3397
  start_longitude: 12.3731
  destination_country: DE
  destination_address: "Dresden, Germany"
  destination_latitude: 51.0504
  destination_longitude: 13.7373
  distance_km: 119
  pickup_date_from: 2025-10-01 09:00:00
  delivery_date_from: 2025-10-02 10:00:00
  driver_language: de
```

**Key Points:**
- **Cover all states/modes:** packages, loading_meters, vehicle_booking, completed
- **Use static dates** (not ERB `2.days.from_now` - causes errors)
- **Realistic coordinates** for German cities
- **Valid enum values** (`status`, `shipping_mode`, `vehicle_type` must match model validations)

### Step 1.3: Create Child Fixtures

#### Example: PackageItem Fixture

**File:** `test/fixtures/package_items.yml`

```yaml
euro_pallet_one:
  transport_request: packages_mode  # References transport_requests.yml label
  package_type: euro_pallet
  quantity: 2
  length_cm: 120
  width_cm: 80
  height_cm: 144
  weight_kg: 300.00

industrial_pallet_one:
  transport_request: packages_mode
  package_type: industrial_pallet
  quantity: 1
  length_cm: 120
  width_cm: 100
  height_cm: 144
  weight_kg: 400.00

half_pallet_one:
  transport_request: completed_request
  package_type: half_pallet
  quantity: 4
  length_cm: 60
  width_cm: 80
  height_cm: 144
  weight_kg: 150.00

custom_box_one:
  transport_request: completed_request
  package_type: custom_box
  quantity: 1
  length_cm: 50
  width_cm: 50
  height_cm: 50
  weight_kg: 25.00
```

**Key Points:**
- **Realistic industry data** (Euro pallet = 120x80x144cm)
- **Different package types** to test type-specific logic
- **Different quantities** to test calculations
- **Valid foreign keys** (transport_request references must exist)

### Step 1.4: Verify Fixtures Load

```bash
rails db:fixtures:load RAILS_ENV=test
```

**Expected output:** Silent success (no errors)

**If you get errors:**

❌ **Foreign key violation:**
```
RuntimeError: Foreign key violations found: package_items
```
**Fix:** Check that all `transport_request:` references match labels in `transport_requests.yml`

❌ **Missing column:**
```
ActiveRecord::Fixture::FixtureError: table "package_items" has no columns named "display_order"
```
**Fix:** Remove `display_order` from fixture (column doesn't exist in schema)

❌ **ERB template error:**
```
ArgumentError: wrong number of arguments (given 1, expected 0)
```
**Fix:** Replace ERB date helpers with static dates:
```yaml
# Bad
pickup_date_from: <%= 2.days.from_now.to_s(:db) %>

# Good
pickup_date_from: 2025-10-10 09:00:00
```

---

## Phase 2: Write Model Unit Tests

### Step 2.1: Create Test File Structure

**File:** `test/models/package_item_test.rb`

```ruby
require "test_helper"

class PackageItemTest < ActiveSupport::TestCase
  # ========== ASSOCIATIONS ==========

  # ========== VALIDATIONS - REQUIRED FIELDS ==========

  # ========== VALIDATIONS - NUMERICALITY ==========

  # ========== OPTIONAL VALIDATIONS ==========

  # ========== CUSTOM METHODS ==========

  # ========== DATABASE CONSTRAINTS ==========

  # ========== FIXTURE DATA VALIDATION ==========
end
```

**Why sections?**
- **Organization:** Easy to find specific test types
- **Readability:** Clear test intent
- **Maintainability:** Add new tests in the right section

### Step 2.2: Write Association Tests

**Goal:** Verify relationships are defined correctly.

```ruby
# ========== ASSOCIATIONS ==========

test "should belong to transport_request" do
  package_item = package_items(:euro_pallet_one)
  assert_respond_to package_item, :transport_request
  assert_instance_of TransportRequest, package_item.transport_request
end

test "should have inverse_of association" do
  transport_request = transport_requests(:packages_mode)
  package_item = transport_request.package_items.build(
    package_type: "test",
    quantity: 1,
    weight_kg: 100
  )

  assert_equal transport_request, package_item.transport_request
end
```

**What this tests:**
- `assert_respond_to`: Model has the association method
- `assert_instance_of`: Association returns correct class
- `inverse_of`: Bidirectional association works (critical for `accepts_nested_attributes_for`)

### Step 2.3: Write Validation Tests

#### Required Field Validations

```ruby
# ========== VALIDATIONS - REQUIRED FIELDS ==========

test "should require package_type" do
  package_item = PackageItem.new(
    transport_request: transport_requests(:packages_mode),
    quantity: 1,
    weight_kg: 100
  )

  assert_not package_item.valid?
  assert_includes package_item.errors[:package_type], "can't be blank"
end

test "should require quantity" do
  package_item = PackageItem.new(
    transport_request: transport_requests(:packages_mode),
    package_type: "euro_pallet",
    quantity: nil,  # Explicitly nil because schema has default: 1
    weight_kg: 100
  )

  assert_not package_item.valid?
  assert_includes package_item.errors[:quantity], "can't be blank"
end

test "should require weight_kg" do
  package_item = PackageItem.new(
    transport_request: transport_requests(:packages_mode),
    package_type: "euro_pallet",
    quantity: 1
  )

  assert_not package_item.valid?
  assert_includes package_item.errors[:weight_kg], "can't be blank"
end
```

**Critical Pattern:** If the schema has `default:`, explicitly set `nil` to test presence validation.

#### Numericality Validations

```ruby
# ========== VALIDATIONS - NUMERICALITY ==========

test "quantity must be an integer" do
  package_item = PackageItem.new(
    transport_request: transport_requests(:packages_mode),
    package_type: "euro_pallet",
    quantity: 1.5,
    weight_kg: 100
  )

  assert_not package_item.valid?
  assert_includes package_item.errors[:quantity], "must be an integer"
end

test "quantity must be greater than zero" do
  package_item = PackageItem.new(
    transport_request: transport_requests(:packages_mode),
    package_type: "euro_pallet",
    quantity: 0,
    weight_kg: 100
  )

  assert_not package_item.valid?
  assert_includes package_item.errors[:quantity], "must be greater than 0"
end

test "weight_kg must be greater than zero" do
  package_item = PackageItem.new(
    transport_request: transport_requests(:packages_mode),
    package_type: "euro_pallet",
    quantity: 1,
    weight_kg: 0
  )

  assert_not package_item.valid?
  assert_includes package_item.errors[:weight_kg], "must be greater than 0"
end
```

#### Optional Field Validations

```ruby
# ========== OPTIONAL VALIDATIONS ==========

test "can save with nil dimensions" do
  package_item = PackageItem.new(
    transport_request: transport_requests(:packages_mode),
    package_type: "custom_box",
    quantity: 1,
    weight_kg: 50,
    length_cm: nil,
    width_cm: nil,
    height_cm: nil
  )

  assert package_item.valid?
end

test "length_cm must be greater than zero if present" do
  package_item = PackageItem.new(
    transport_request: transport_requests(:packages_mode),
    package_type: "euro_pallet",
    quantity: 1,
    weight_kg: 100,
    length_cm: 0
  )

  assert_not package_item.valid?
  assert_includes package_item.errors[:length_cm], "must be greater than 0"
end
```

**Pattern:** Test both `nil` (allowed) and `0` (rejected) for optional fields with numericality constraints.

### Step 2.4: Write Custom Method Tests

```ruby
# ========== CUSTOM METHODS ==========

test "total_weight calculates correctly" do
  package_item = PackageItem.new(
    transport_request: transport_requests(:packages_mode),
    package_type: "euro_pallet",
    quantity: 3,
    weight_kg: 100.5
  )

  assert_equal 301.5, package_item.total_weight
end

test "total_weight handles nil weight_kg" do
  package_item = PackageItem.new(
    transport_request: transport_requests(:packages_mode),
    package_type: "euro_pallet",
    quantity: 3,
    weight_kg: nil
  )

  assert_equal 0, package_item.total_weight
end
```

**Pattern:** Test the happy path AND edge cases (nil values, zero, negative).

### Step 2.5: Write Database Constraint Tests

```ruby
# ========== DATABASE CONSTRAINTS ==========

test "foreign key constraint enforced" do
  package_item = PackageItem.new(
    package_type: "euro_pallet",
    quantity: 1,
    weight_kg: 100
  )

  # Should fail without transport_request
  assert_raises(ActiveRecord::RecordInvalid) do
    package_item.save!
  end
end

test "references transport_request correctly" do
  package_item = package_items(:euro_pallet_one)
  assert_equal transport_requests(:packages_mode), package_item.transport_request
end
```

### Step 2.6: Write Fixture Validation Test

```ruby
# ========== FIXTURE DATA VALIDATION ==========

test "fixture data is valid" do
  assert package_items(:euro_pallet_one).valid?
  assert package_items(:industrial_pallet_one).valid?
  assert package_items(:half_pallet_one).valid?
  assert package_items(:custom_box_one).valid?
end
```

**Why?** This test catches fixture errors early. If a fixture is invalid, all other tests will fail with confusing errors.

---

## Phase 3: Run and Debug Tests

### Step 3.1: Run Single Test File

```bash
rails test test/models/package_item_test.rb
```

**Expected output:**
```
Running 19 tests in a single process (parallelization threshold is 50)
Run options: --seed 25386

# Running:

...................

Finished in 0.262583s, 72.3581 runs/s, 182.7993 assertions/s.
19 runs, 48 assertions, 0 failures, 0 errors, 0 skips
```

### Step 3.2: Debug Failing Tests

#### Common Error 1: Validation Mismatch

**Error:**
```
Failure:
PackageItemTest#test_should_require_weight_kg [test/models/package_item_test.rb:53]:
Expected [] to include "can't be blank".
```

**Cause:** Model doesn't have `validates :weight_kg, presence: true`

**Fix:** Add validation to model:
```ruby
# app/models/package_item.rb
validates :weight_kg, presence: true, numericality: { greater_than: 0 }
```

#### Common Error 2: Incorrect Error Message

**Error:**
```
Failure:
PackageItemTest#test_quantity_must_be_an_integer [test/models/package_item_test.rb:66]:
Expected [] to include "must be an integer".
```

**Cause:** Validation uses `numericality: { greater_than: 0 }` but test expects `only_integer: true`

**Fix:** Update model validation:
```ruby
# app/models/package_item.rb
validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
```

#### Common Error 3: Default Value in Schema

**Error:**
```
Failure:
PackageItemTest#test_should_require_quantity [test/models/package_item_test.rb:41]:
Expected true to be nil or false
```

**Cause:** Schema has `default: 1` for quantity, so it's never blank unless explicitly set to `nil`

**Fix:** Update test to explicitly set `nil`:
```ruby
test "should require quantity" do
  package_item = PackageItem.new(
    transport_request: transport_requests(:packages_mode),
    package_type: "euro_pallet",
    quantity: nil,  # ADD THIS
    weight_kg: 100
  )

  assert_not package_item.valid?
  assert_includes package_item.errors[:quantity], "can't be blank"
end
```

### Step 3.3: Run All Model Tests

```bash
rails test test/models/
```

**Expected output:**
```
Running 71 tests in parallel using 10 processes
Run options: --seed 60032

# Running:

.......................................................................

Finished in 0.934765s, 75.9549 runs/s, 189.3524 assertions/s.
71 runs, 177 assertions, 0 failures, 0 errors, 0 skips
```

---

## Common Patterns

### Testing Scopes

```ruby
test "active scope excludes cancelled and delivered" do
  active_requests = TransportRequest.active

  assert_not active_requests.include?(transport_requests(:completed_request))
  assert active_requests.include?(transport_requests(:packages_mode))
end

test "recent scope orders by created_at desc" do
  recent_requests = TransportRequest.recent.limit(2)

  assert recent_requests.first.created_at >= recent_requests.last.created_at
end
```

### Testing Enum/Inclusion Validations

```ruby
test "status must be valid if present" do
  transport_request = TransportRequest.new(
    user: users(:customer_one),
    start_address: "Berlin, Germany",
    destination_address: "Munich, Germany",
    pickup_date_from: 1.day.from_now,
    status: "invalid_status"
  )

  assert_not transport_request.valid?
  assert_includes transport_request.errors[:status], "is not included in the list"
end

test "status can be new, matched, delivered, or cancelled" do
  %w[new matched delivered cancelled].each do |status|
    transport_request = TransportRequest.new(
      user: users(:customer_one),
      start_address: "Berlin, Germany",
      destination_address: "Munich, Germany",
      pickup_date_from: 1.day.from_now,
      status: status
    )

    assert transport_request.valid?, "#{status} should be valid"
  end
end
```

### Testing Conditional Validations

```ruby
test "loading_meters required when shipping_mode is loading_meters" do
  transport_request = TransportRequest.new(
    user: users(:customer_one),
    start_address: "Berlin, Germany",
    destination_address: "Munich, Germany",
    pickup_date_from: 1.day.from_now,
    shipping_mode: "loading_meters"
  )

  assert_not transport_request.valid?
  assert_includes transport_request.errors[:loading_meters], "can't be blank"
end

test "loading_meters not required when shipping_mode is packages" do
  transport_request = TransportRequest.new(
    user: users(:customer_one),
    start_address: "Berlin, Germany",
    destination_address: "Munich, Germany",
    pickup_date_from: 1.day.from_now,
    shipping_mode: "packages"
  )

  assert transport_request.valid?
end
```

### Testing Nested Attributes

```ruby
test "can create package_items through nested attributes" do
  transport_request = TransportRequest.new(
    user: users(:customer_one),
    start_address: "Berlin, Germany",
    destination_address: "Munich, Germany",
    pickup_date_from: 1.day.from_now,
    shipping_mode: "packages",
    package_items_attributes: [
      {
        package_type: "euro_pallet",
        quantity: 2,
        length_cm: 120,
        width_cm: 80,
        height_cm: 144,
        weight_kg: 300
      }
    ]
  )

  assert transport_request.valid?
  assert transport_request.save
  assert_equal 1, transport_request.package_items.count
end

test "can destroy package_items through nested attributes" do
  transport_request = transport_requests(:packages_mode)
  package_item = transport_request.package_items.first

  transport_request.update(
    package_items_attributes: [
      {
        id: package_item.id,
        _destroy: "1"
      }
    ]
  )

  assert_not transport_request.package_items.include?(package_item)
end

test "rejects blank package_items in nested attributes" do
  transport_request = TransportRequest.new(
    user: users(:customer_one),
    start_address: "Berlin, Germany",
    destination_address: "Munich, Germany",
    pickup_date_from: 1.day.from_now,
    shipping_mode: "packages",
    package_items_attributes: [
      {
        package_type: "",
        quantity: nil,
        weight_kg: nil
      }
    ]
  )

  assert transport_request.valid?
  assert_equal 0, transport_request.package_items.size
end
```

### Testing Dependent Destroy

```ruby
test "should destroy dependent package_items when destroyed" do
  transport_request = transport_requests(:packages_mode)
  package_item_ids = transport_request.package_items.pluck(:id)

  transport_request.destroy

  package_item_ids.each do |id|
    assert_nil PackageItem.find_by(id: id)
  end
end
```

### Testing Custom Validations

```ruby
test "delivery_date_from must be after pickup_date_from" do
  transport_request = TransportRequest.new(
    user: users(:customer_one),
    start_address: "Berlin, Germany",
    destination_address: "Munich, Germany",
    pickup_date_from: 2.days.from_now,
    delivery_date_from: 1.day.from_now
  )

  assert_not transport_request.valid?
  assert_includes transport_request.errors[:delivery_date_from], "must be after pickup date"
end

test "delivery_date_from can be same as pickup_date_from" do
  date = 2.days.from_now
  transport_request = TransportRequest.new(
    user: users(:customer_one),
    start_address: "Berlin, Germany",
    destination_address: "Munich, Germany",
    pickup_date_from: date,
    delivery_date_from: date
  )

  assert transport_request.valid?
end
```

---

## Troubleshooting

### Foreign Key Violations

**Error:**
```
RuntimeError: Foreign key violations found in your fixture data. Ensure you aren't referring to labels that don't exist on associations. Error from database: Foreign key violations found: carrier_requests
```

**Cause:** Fixture references a label that doesn't exist in the parent fixture.

**Debug steps:**
1. Read the error: "carrier_requests" has the violation
2. Open `test/fixtures/carrier_requests.yml`
3. Check all `transport_request:` and `carrier:` references
4. Verify those labels exist in `transport_requests.yml` and `carriers.yml`

**Example fix:**
```yaml
# Bad (transport_request "one" doesn't exist)
packages_berlin_express:
  transport_request: one
  carrier: berlin_express_transport

# Good (packages_mode exists in transport_requests.yml)
packages_berlin_express:
  transport_request: packages_mode
  carrier: berlin_express_transport
```

### ERB Template Errors

**Error:**
```
ArgumentError: wrong number of arguments (given 1, expected 0)
```

**Cause:** Using complex ERB in fixtures (e.g., `2.days.from_now.to_s(:db)`)

**Fix:** Use static dates
```yaml
# Bad
pickup_date_from: <%= 2.days.from_now.to_s(:db) %>

# Good
pickup_date_from: 2025-10-10 09:00:00
```

### Missing Columns

**Error:**
```
ActiveRecord::Fixture::FixtureError: table "package_type_presets" has no columns named "display_order"
```

**Cause:** Fixture includes a column that doesn't exist in the database schema.

**Fix:** Remove the column from the fixture or add a migration.

### Invalid Enum Values

**Error (in test output):**
```
Failure:
TransportRequestTest#test_fixture_data_is_valid [test/models/transport_request_test.rb:438]:
Expected false to be truthy.
```

**Debug:**
```bash
rails console -e test
```

```ruby
tr = TransportRequest.find_by(shipping_mode: 'vehicle_booking')
tr.valid?
tr.errors.full_messages
# => ["Vehicle type is not included in the list"]
```

**Cause:** Fixture has `vehicle_type: sprinter` but model only allows `transporter`, `lkw`, `either`

**Fix:** Update fixture with valid enum value:
```yaml
vehicle_booking_mode:
  vehicle_type: lkw  # Changed from 'sprinter'
```

---

## Best Practices

### 1. Test Organization

✅ **Good:**
```ruby
class PackageItemTest < ActiveSupport::TestCase
  # ========== ASSOCIATIONS ==========
  test "should belong to transport_request" do
    # ...
  end

  # ========== VALIDATIONS - REQUIRED FIELDS ==========
  test "should require package_type" do
    # ...
  end
end
```

❌ **Bad:**
```ruby
class PackageItemTest < ActiveSupport::TestCase
  test "test_1" do
    # ...
  end

  test "test_2" do
    # ...
  end
end
```

### 2. Descriptive Test Names

✅ **Good:**
```ruby
test "quantity must be an integer"
test "loading_meters required when shipping_mode is loading_meters"
test "can destroy package_items through nested attributes"
```

❌ **Bad:**
```ruby
test "validation"
test "test quantity"
test "nested attrs"
```

### 3. One Assertion Per Concept

✅ **Good:**
```ruby
test "should require package_type" do
  package_item = PackageItem.new(quantity: 1, weight_kg: 100)

  assert_not package_item.valid?
  assert_includes package_item.errors[:package_type], "can't be blank"
end
```

❌ **Bad:**
```ruby
test "validations" do
  package_item = PackageItem.new

  assert_not package_item.valid?
  assert_includes package_item.errors[:package_type], "can't be blank"
  assert_includes package_item.errors[:quantity], "can't be blank"
  assert_includes package_item.errors[:weight_kg], "can't be blank"
end
```

**Why?** If the first assertion fails, the test stops and you don't see which other validations are broken.

### 4. Use Realistic Fixture Data

✅ **Good:**
```yaml
euro_pallet_one:
  package_type: euro_pallet
  quantity: 2
  length_cm: 120  # Actual Euro pallet dimensions
  width_cm: 80
  height_cm: 144
  weight_kg: 300.00
```

❌ **Bad:**
```yaml
one:
  package_type: MyString
  quantity: 1
  length_cm: 1
  width_cm: 1
  height_cm: 1
  weight_kg: 9.99
```

**Why?** Realistic data catches bugs that toy data won't (e.g., max loading meter is 13.6, not 999).

### 5. Cover Edge Cases

```ruby
# Test nil (optional field)
test "can save with nil dimensions" do
  package_item = PackageItem.new(
    transport_request: transport_requests(:packages_mode),
    package_type: "custom_box",
    quantity: 1,
    weight_kg: 50,
    length_cm: nil,
    width_cm: nil,
    height_cm: nil
  )

  assert package_item.valid?
end

# Test zero (boundary)
test "length_cm must be greater than zero if present" do
  package_item = PackageItem.new(
    transport_request: transport_requests(:packages_mode),
    package_type: "euro_pallet",
    quantity: 1,
    weight_kg: 100,
    length_cm: 0
  )

  assert_not package_item.valid?
  assert_includes package_item.errors[:length_cm], "must be greater than 0"
end

# Test negative (invalid)
test "quantity cannot be negative" do
  package_item = PackageItem.new(
    transport_request: transport_requests(:packages_mode),
    package_type: "euro_pallet",
    quantity: -1,
    weight_kg: 100
  )

  assert_not package_item.valid?
  assert_includes package_item.errors[:quantity], "must be greater than 0"
end

# Test decimal precision
test "can save with decimal weight" do
  package_item = PackageItem.new(
    transport_request: transport_requests(:packages_mode),
    package_type: "custom_box",
    quantity: 1,
    weight_kg: 9.99
  )

  assert package_item.valid?
  assert package_item.save
  assert_equal 9.99, package_item.weight_kg
end
```

### 6. Test Fixture Validity First

**Always include:**
```ruby
test "fixture data is valid" do
  assert package_items(:euro_pallet_one).valid?
  assert package_items(:industrial_pallet_one).valid?
  assert package_items(:half_pallet_one).valid?
  assert package_items(:custom_box_one).valid?
end
```

**Why?** If fixtures are invalid, all other tests will fail with confusing errors.

---

## Example: Complete Test Suite

Here's a complete example for `PackageItem`:

```ruby
require "test_helper"

class PackageItemTest < ActiveSupport::TestCase
  # ========== ASSOCIATIONS ==========

  test "should belong to transport_request" do
    package_item = package_items(:euro_pallet_one)
    assert_respond_to package_item, :transport_request
    assert_instance_of TransportRequest, package_item.transport_request
  end

  test "should have inverse_of association" do
    transport_request = transport_requests(:packages_mode)
    package_item = transport_request.package_items.build(
      package_type: "test",
      quantity: 1,
      weight_kg: 100
    )

    assert_equal transport_request, package_item.transport_request
  end

  # ========== VALIDATIONS - REQUIRED FIELDS ==========

  test "should require package_type" do
    package_item = PackageItem.new(
      transport_request: transport_requests(:packages_mode),
      quantity: 1,
      weight_kg: 100
    )

    assert_not package_item.valid?
    assert_includes package_item.errors[:package_type], "can't be blank"
  end

  test "should require quantity" do
    package_item = PackageItem.new(
      transport_request: transport_requests(:packages_mode),
      package_type: "euro_pallet",
      quantity: nil,
      weight_kg: 100
    )

    assert_not package_item.valid?
    assert_includes package_item.errors[:quantity], "can't be blank"
  end

  test "should require weight_kg" do
    package_item = PackageItem.new(
      transport_request: transport_requests(:packages_mode),
      package_type: "euro_pallet",
      quantity: 1
    )

    assert_not package_item.valid?
    assert_includes package_item.errors[:weight_kg], "can't be blank"
  end

  # ========== VALIDATIONS - NUMERICALITY ==========

  test "quantity must be an integer" do
    package_item = PackageItem.new(
      transport_request: transport_requests(:packages_mode),
      package_type: "euro_pallet",
      quantity: 1.5,
      weight_kg: 100
    )

    assert_not package_item.valid?
    assert_includes package_item.errors[:quantity], "must be an integer"
  end

  test "quantity must be greater than zero" do
    package_item = PackageItem.new(
      transport_request: transport_requests(:packages_mode),
      package_type: "euro_pallet",
      quantity: 0,
      weight_kg: 100
    )

    assert_not package_item.valid?
    assert_includes package_item.errors[:quantity], "must be greater than 0"
  end

  test "weight_kg must be greater than zero" do
    package_item = PackageItem.new(
      transport_request: transport_requests(:packages_mode),
      package_type: "euro_pallet",
      quantity: 1,
      weight_kg: 0
    )

    assert_not package_item.valid?
    assert_includes package_item.errors[:weight_kg], "must be greater than 0"
  end

  # ========== OPTIONAL DIMENSION VALIDATIONS ==========

  test "can save with nil dimensions" do
    package_item = PackageItem.new(
      transport_request: transport_requests(:packages_mode),
      package_type: "custom_box",
      quantity: 1,
      weight_kg: 50,
      length_cm: nil,
      width_cm: nil,
      height_cm: nil
    )

    assert package_item.valid?
  end

  test "length_cm must be greater than zero if present" do
    package_item = PackageItem.new(
      transport_request: transport_requests(:packages_mode),
      package_type: "euro_pallet",
      quantity: 1,
      weight_kg: 100,
      length_cm: 0
    )

    assert_not package_item.valid?
    assert_includes package_item.errors[:length_cm], "must be greater than 0"
  end

  # ========== EDGE CASES ==========

  test "can save with decimal weight" do
    package_item = PackageItem.new(
      transport_request: transport_requests(:packages_mode),
      package_type: "custom_box",
      quantity: 1,
      weight_kg: 9.99
    )

    assert package_item.valid?
    assert package_item.save
    assert_equal 9.99, package_item.weight_kg
  end

  # ========== DATABASE CONSTRAINTS ==========

  test "references transport_request correctly" do
    package_item = package_items(:euro_pallet_one)
    assert_equal transport_requests(:packages_mode), package_item.transport_request
  end

  test "foreign key constraint enforced" do
    package_item = PackageItem.new(
      package_type: "euro_pallet",
      quantity: 1,
      weight_kg: 100
    )

    assert_raises(ActiveRecord::RecordInvalid) do
      package_item.save!
    end
  end

  # ========== FIXTURE DATA VALIDATION ==========

  test "fixture data is valid" do
    assert package_items(:euro_pallet_one).valid?
    assert package_items(:industrial_pallet_one).valid?
    assert package_items(:half_pallet_one).valid?
    assert package_items(:custom_box_one).valid?
  end
end
```

**Result:** 19 tests, 48 assertions, 0 failures ✅

---

## Checklist

Use this checklist for each model:

### Fixtures
- [ ] Parent fixtures created (User, TransportRequest, etc.)
- [ ] Child fixtures created (PackageItem, CarrierRequest, etc.)
- [ ] Foreign key references are correct
- [ ] All required fields populated
- [ ] Realistic data used
- [ ] Multiple states/types covered
- [ ] Edge cases included (nil, zero, max values)
- [ ] Fixtures load without errors: `rails db:fixtures:load RAILS_ENV=test`

### Tests
- [ ] Association tests (belongs_to, has_many, inverse_of)
- [ ] Required field validations
- [ ] Numericality validations (integer, greater_than, less_than)
- [ ] Inclusion validations (enum, allowed values)
- [ ] Conditional validations (if/unless)
- [ ] Custom validations
- [ ] Scopes (if any)
- [ ] Custom methods (calculations, business logic)
- [ ] Nested attributes (if `accepts_nested_attributes_for`)
- [ ] Database constraints (foreign keys, uniqueness)
- [ ] Fixture validity test
- [ ] Edge cases (nil, zero, negative, decimal precision)

### Verification
- [ ] All tests pass: `rails test test/models/your_model_test.rb`
- [ ] No warnings in output
- [ ] Coverage is comprehensive (80%+)
- [ ] Test names are descriptive
- [ ] Tests are organized into sections
- [ ] Code committed to git

---

## Related Files

**Models:**
- `app/models/package_item.rb`
- `app/models/transport_request.rb`
- `app/models/package_type_preset.rb`

**Fixtures:**
- `test/fixtures/users.yml`
- `test/fixtures/transport_requests.yml`
- `test/fixtures/package_items.yml`
- `test/fixtures/package_type_presets.yml`
- `test/fixtures/carriers.yml`
- `test/fixtures/carrier_requests.yml`

**Tests:**
- `test/models/package_item_test.rb` (19 tests)
- `test/models/transport_request_test.rb` (37 tests)
- `test/models/package_type_preset_test.rb` (15 tests)

**Task Plan:**
- `.agent/Tasks/comprehensive_testing_implementation.md`

---

**Last Updated:** 2025-10-08
**Next Review:** 2025-11-08
