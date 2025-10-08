# Implementing Controller Tests with Minitest

**Last Updated:** 2025-10-08
**Author:** Claude Code
**Related Docs:**
- [Implementing Comprehensive Unit Tests](./implementing_comprehensive_unit_tests.md)
- [Comprehensive Testing Implementation](../Tasks/comprehensive_testing_implementation.md)
- [Project Architecture](../System/project_architecture.md)
- [Authentication & Authorization](../System/authentication_authorization.md)

---

## Overview

This SOP guides you through implementing comprehensive controller tests using Rails 8's Minitest framework with `ActionDispatch::IntegrationTest`. Controller tests verify HTTP request/response behavior, authentication, authorization, CRUD operations, and complex workflows like multi-mode cargo management with nested attributes.

**When to use this SOP:**
- After creating or modifying controllers
- When implementing multi-step workflows
- When testing role-based access control
- When working with nested attributes and complex forms

---

## Prerequisites

### Required Gems

Ensure your `Gemfile` includes:

```ruby
group :test do
  gem "capybara"
  gem "selenium-webdriver"

  # Controller testing helpers (assigns, assert_template)
  gem "rails-controller-testing"
end
```

Run `bundle install` after adding gems.

### Test Helper Configuration

Add Devise test helpers to `test/test_helper.rb`:

```ruby
# test/test_helper.rb
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all
  end
end

# Add Devise test helpers for controller tests
class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
```

---

## Step 1: Analyze the Controller

Before writing tests, thoroughly understand the controller:

### Read the Source Code

```bash
# Example: Admin TransportRequests controller
cat app/controllers/admin/transport_requests_controller.rb
```

**Document:**
1. **All actions**: index, show, new, create, edit, update, destroy, custom actions
2. **Before filters**: authentication, authorization, record loading
3. **Strong parameters**: permitted attributes, nested attributes
4. **Business logic**: geocoding, background jobs, state transitions
5. **Redirects and renders**: success/failure paths

### Read Related Models

```bash
cat app/models/transport_request.rb
cat app/models/package_item.rb
```

**Document:**
1. Validations (presence, numericality, inclusion, custom)
2. Associations (belongs_to, has_many, nested attributes)
3. Scopes and callbacks
4. Business logic methods

### Read Authorization Helpers

```bash
cat app/controllers/application_controller.rb
cat app/models/user.rb
```

**Document:**
1. Authorization methods (`ensure_admin!`, `ensure_customer!`)
2. User role methods (`admin?`, `customer?`, `admin_or_dispatcher?`)
3. Layout routing logic

---

## Step 2: Set Up Test File Structure

Create the test file with proper organization:

```ruby
# test/controllers/admin/transport_requests_controller_test.rb
require "test_helper"

class Admin::TransportRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Stub external services (Geocoder, APIs, etc.)
    Geocoder.configure(lookup: :test, ip_lookup: :test)

    Geocoder::Lookup::Test.add_stub(
      "Berlin, Germany", [
        {
          'coordinates' => [52.5200, 13.4050],
          'country_code' => 'DE'
        }
      ]
    )

    Geocoder::Lookup::Test.add_stub(
      "Munich, Germany", [
        {
          'coordinates' => [48.1351, 11.5820],
          'country_code' => 'DE'
        }
      ]
    )

    # Load fixtures
    @admin = users(:admin_user)
    @dispatcher = users(:dispatcher_user)
    @customer = users(:customer_one)
    @transport_request = transport_requests(:packages_mode)
  end

  teardown do
    # Reset stubs
    Geocoder::Lookup::Test.reset
  end

  # Tests organized by concern...
end
```

---

## Step 3: Test Organization Pattern

Organize tests into logical sections using comments:

```ruby
# ========== AUTHENTICATION & AUTHORIZATION ==========
# Tests for login requirements and role-based access

# ========== INDEX ACTION ==========
# Tests for listing resources

# ========== SHOW ACTION ==========
# Tests for displaying single resource

# ========== NEW ACTION ==========
# Tests for rendering creation form

# ========== CREATE ACTION - [MODE/VARIANT] ==========
# Tests for creating resources (group by mode if applicable)

# ========== EDIT ACTION ==========
# Tests for rendering edit form

# ========== UPDATE ACTION ==========
# Tests for updating resources

# ========== DESTROY ACTION ==========
# Tests for deleting resources

# ========== CUSTOM ACTIONS ==========
# Tests for non-RESTful actions (run_matching, cancel, etc.)

# ========== STRONG PARAMETERS ==========
# Tests for parameter filtering

# ========== EDGE CASES ==========
# Tests for error handling, validation failures, etc.
```

---

## Step 4: Write Authentication & Authorization Tests

Test authentication requirements and role-based access:

```ruby
# ========== AUTHENTICATION & AUTHORIZATION ==========

test "should require authentication for index" do
  get admin_transport_requests_url
  assert_redirected_to new_user_session_path
end

test "should allow admin access" do
  sign_in @admin
  get admin_transport_requests_url
  assert_response :success
end

test "should allow dispatcher access" do
  sign_in @dispatcher
  get admin_transport_requests_url
  assert_response :success
end

test "should deny customer access to index" do
  sign_in @customer
  get admin_transport_requests_url
  assert_redirected_to root_path
  assert_equal "Access denied. Admin privileges required.", flash[:alert]
end

test "should deny customer access to create" do
  sign_in @customer
  post admin_transport_requests_url, params: { transport_request: {} }
  assert_redirected_to root_path
end

test "should deny customer access to update" do
  sign_in @customer
  patch admin_transport_request_url(@transport_request), params: { transport_request: {} }
  assert_redirected_to root_path
end
```

---

## Step 5: Write CRUD Tests

### Index Action

```ruby
# ========== INDEX ACTION ==========

test "index lists all transport requests" do
  sign_in @admin
  get admin_transport_requests_url

  assert_response :success
  assert_not_nil assigns(:transport_requests)
end

test "index orders by created_at desc" do
  sign_in @admin
  get admin_transport_requests_url

  requests = assigns(:transport_requests)
  assert requests.first.created_at >= requests.last.created_at if requests.count > 1
end
```

### Show Action

```ruby
# ========== SHOW ACTION ==========

test "show displays transport request" do
  sign_in @admin
  get admin_transport_request_url(@transport_request)

  assert_response :success
  assert_equal @transport_request, assigns(:transport_request)
end

test "show loads carrier requests" do
  sign_in @admin
  get admin_transport_request_url(@transport_request)

  assert_not_nil assigns(:carrier_requests)
end
```

### New Action

```ruby
# ========== NEW ACTION ==========

test "new renders form" do
  sign_in @admin
  get new_admin_transport_request_url

  assert_response :success
  assert_not_nil assigns(:transport_request)
  assert assigns(:transport_request).new_record?
end
```

### Create Action

```ruby
# ========== CREATE ACTION - PACKAGES MODE ==========

test "create with packages mode and nested package_items" do
  sign_in @admin

  assert_difference('TransportRequest.count', 1) do
    assert_difference('PackageItem.count', 2) do
      post admin_transport_requests_url, params: {
        transport_request: {
          shipping_mode: 'packages',
          start_address: 'Berlin, Germany',
          destination_address: 'Munich, Germany',
          pickup_date_from: 2.days.from_now,
          delivery_date_from: 3.days.from_now,
          package_items_attributes: [
            {
              package_type: 'euro_pallet',
              quantity: 2,
              length_cm: 120,
              width_cm: 80,
              height_cm: 144,
              weight_kg: 300
            },
            {
              package_type: 'industrial_pallet',
              quantity: 1,
              length_cm: 120,
              width_cm: 100,
              height_cm: 144,
              weight_kg: 400
            }
          ]
        }
      }
    end
  end

  request = TransportRequest.last
  assert_equal 'packages', request.shipping_mode
  assert_equal 'new', request.status
  assert_equal 2, request.package_items.count
  assert_redirected_to admin_transport_request_path(request)
end

test "create with packages mode geocodes addresses" do
  sign_in @admin

  post admin_transport_requests_url, params: {
    transport_request: {
      shipping_mode: 'packages',
      start_address: 'Berlin, Germany',
      destination_address: 'Munich, Germany',
      pickup_date_from: 2.days.from_now,
      package_items_attributes: [
        { package_type: 'euro_pallet', quantity: 1, weight_kg: 100 }
      ]
    }
  }

  request = TransportRequest.last
  assert_equal 52.5200, request.start_latitude
  assert_equal 13.4050, request.start_longitude
  assert_equal 'DE', request.start_country
  assert_equal 48.1351, request.destination_latitude
  assert_equal 11.5820, request.destination_longitude
  assert_equal 'DE', request.destination_country
  assert_not_nil request.distance_km
end

test "create with packages mode requires package_items" do
  sign_in @admin

  post admin_transport_requests_url, params: {
    transport_request: {
      shipping_mode: 'packages',
      start_address: 'Berlin, Germany',
      destination_address: 'Munich, Germany',
      pickup_date_from: 2.days.from_now
      # No package_items_attributes
    }
  }

  assert_response :unprocessable_entity
  assert_template :new
end

test "create with packages mode preserves data on validation error" do
  sign_in @admin

  post admin_transport_requests_url, params: {
    transport_request: {
      shipping_mode: 'packages',
      # Missing required start_address
      destination_address: 'Munich, Germany',
      pickup_date_from: 2.days.from_now,
      package_items_attributes: [
        { package_type: 'euro_pallet', quantity: 2, weight_kg: 300 }
      ]
    }
  }

  assert_response :unprocessable_entity
  assert_template :new
  request = assigns(:transport_request)
  assert_equal 'packages', request.shipping_mode
  assert_equal 1, request.package_items.size
end
```

---

## Step 6: Test Complex Workflows

### Multi-Mode Support

For controllers with multiple modes (packages, loading_meters, vehicle_booking):

```ruby
# ========== CREATE ACTION - LOADING METERS MODE ==========

test "create with loading_meters mode" do
  sign_in @admin

  assert_difference('TransportRequest.count', 1) do
    post admin_transport_requests_url, params: {
      transport_request: {
        shipping_mode: 'loading_meters',
        loading_meters: 10.5,
        total_height_cm: 260,
        total_weight_kg: 15000,
        start_address: 'Berlin, Germany',
        destination_address: 'Munich, Germany',
        pickup_date_from: 2.days.from_now
      }
    }
  end

  request = TransportRequest.last
  assert_equal 'loading_meters', request.shipping_mode
  assert_equal 10.5, request.loading_meters
  assert_equal 0, request.package_items.count
end

test "create with loading_meters validates max 13.6" do
  sign_in @admin

  post admin_transport_requests_url, params: {
    transport_request: {
      shipping_mode: 'loading_meters',
      loading_meters: 15.0,  # Over max
      total_height_cm: 260,
      total_weight_kg: 15000,
      start_address: 'Berlin, Germany',
      destination_address: 'Munich, Germany',
      pickup_date_from: 2.days.from_now
    }
  }

  assert_response :unprocessable_entity
  assert_template :new
  request = assigns(:transport_request)
  assert_includes request.errors[:loading_meters], "must be less than or equal to 13.6"
end

# ========== CREATE ACTION - VEHICLE BOOKING MODE ==========

test "create with vehicle_booking mode" do
  sign_in @admin

  assert_difference('TransportRequest.count', 1) do
    post admin_transport_requests_url, params: {
      transport_request: {
        shipping_mode: 'vehicle_booking',
        vehicle_type: 'lkw',
        start_address: 'Berlin, Germany',
        destination_address: 'Munich, Germany',
        pickup_date_from: 2.days.from_now
      }
    }
  end

  request = TransportRequest.last
  assert_equal 'vehicle_booking', request.shipping_mode
  assert_equal 'lkw', request.vehicle_type
end
```

### Nested Attributes (Update)

```ruby
# ========== UPDATE ACTION ==========

test "update adds new package_items" do
  sign_in @admin

  assert_difference('@transport_request.package_items.count', 1) do
    patch admin_transport_request_url(@transport_request), params: {
      transport_request: {
        package_items_attributes: [
          {
            package_type: 'half_pallet',
            quantity: 3,
            length_cm: 60,
            width_cm: 80,
            height_cm: 144,
            weight_kg: 150
          }
        ]
      }
    }
    @transport_request.reload
  end

  assert_redirected_to admin_transport_request_path(@transport_request)
  new_item = @transport_request.package_items.find_by(package_type: 'half_pallet')
  assert_not_nil new_item
  assert_equal 3, new_item.quantity
end

test "update removes package_items via _destroy" do
  sign_in @admin
  package_item = @transport_request.package_items.first
  original_count = @transport_request.package_items.count

  patch admin_transport_request_url(@transport_request), params: {
    transport_request: {
      package_items_attributes: [
        { id: package_item.id, _destroy: '1' }
      ]
    }
  }

  assert_redirected_to admin_transport_request_path(@transport_request)
  @transport_request.reload
  assert_equal original_count - 1, @transport_request.package_items.count
  assert_not PackageItem.exists?(package_item.id)
end

test "update modifies existing package_item" do
  sign_in @admin
  package_item = @transport_request.package_items.first

  patch admin_transport_request_url(@transport_request), params: {
    transport_request: {
      package_items_attributes: [
        { id: package_item.id, quantity: 10, weight_kg: 500 }
      ]
    }
  }

  assert_redirected_to admin_transport_request_path(@transport_request)
  package_item.reload
  assert_equal 10, package_item.quantity
  assert_equal 500, package_item.weight_kg
end
```

---

## Step 7: Test Custom Actions

```ruby
# ========== RUN MATCHING ACTION ==========

test "run_matching starts job for new request" do
  sign_in @admin
  @transport_request.update(status: 'new')

  assert_enqueued_with(job: MatchCarriersJob, args: [@transport_request.id]) do
    post run_matching_admin_transport_request_url(@transport_request)
  end

  @transport_request.reload
  assert_equal 'matching', @transport_request.status
  assert_redirected_to admin_transport_request_path(@transport_request)
  assert_equal "Matching process started. Invitations will be sent shortly.", flash[:notice]
end

test "run_matching rejects non-new requests" do
  sign_in @admin
  @transport_request.update(status: 'matched')

  post run_matching_admin_transport_request_url(@transport_request)

  assert_redirected_to admin_transport_request_path(@transport_request)
  assert_equal "Cannot run matching for this request.", flash[:alert]
end

# ========== CANCEL ACTION ==========

test "cancel updates status to cancelled" do
  sign_in @admin

  post cancel_admin_transport_request_url(@transport_request)

  @transport_request.reload
  assert_equal 'cancelled', @transport_request.status
  assert_redirected_to admin_transport_request_path(@transport_request)
end
```

---

## Step 8: Test Strong Parameters

Verify parameter filtering works correctly:

```ruby
# ========== STRONG PARAMETERS ==========

test "create permits shipping_mode" do
  sign_in @admin

  post admin_transport_requests_url, params: {
    transport_request: {
      shipping_mode: 'packages',
      start_address: 'Berlin, Germany',
      destination_address: 'Munich, Germany',
      pickup_date_from: 2.days.from_now,
      package_items_attributes: [
        { package_type: 'euro_pallet', quantity: 1, weight_kg: 100 }
      ]
    }
  }

  assert_equal 'packages', TransportRequest.last.shipping_mode
end

test "create permits package_items_attributes with _destroy" do
  sign_in @admin

  # This is tested indirectly through nested attribute tests
  # Verify _destroy flag is permitted in update
  package_item = @transport_request.package_items.first

  patch admin_transport_request_url(@transport_request), params: {
    transport_request: {
      package_items_attributes: [
        { id: package_item.id, _destroy: '1' }
      ]
    }
  }

  assert_not PackageItem.exists?(package_item.id)
end

test "create filters unpermitted attributes" do
  sign_in @admin

  post admin_transport_requests_url, params: {
    transport_request: {
      shipping_mode: 'packages',
      status: 'delivered',  # Unpermitted - should be ignored
      matched_carrier_id: 999,  # Unpermitted - should be ignored
      start_address: 'Berlin, Germany',
      destination_address: 'Munich, Germany',
      pickup_date_from: 2.days.from_now,
      package_items_attributes: [
        { package_type: 'euro_pallet', quantity: 1, weight_kg: 100 }
      ]
    }
  }

  request = TransportRequest.last
  assert_equal 'new', request.status  # Should be set by controller, not params
  assert_nil request.matched_carrier_id
end
```

---

## Step 9: Test Edge Cases

```ruby
# ========== EDGE CASES ==========

test "switching modes on update clears package_items" do
  sign_in @admin
  package_item_ids = @transport_request.package_items.pluck(:id)

  patch admin_transport_request_url(@transport_request), params: {
    transport_request: {
      shipping_mode: 'loading_meters',
      loading_meters: 12.0,
      total_height_cm: 260,
      total_weight_kg: 18000,
      package_items_attributes: package_item_ids.map { |id| { id: id, _destroy: '1' } }
    }
  }

  @transport_request.reload
  assert_equal 'loading_meters', @transport_request.shipping_mode
  assert_equal 0, @transport_request.package_items.count
end

test "destroy removes transport_request and dependencies" do
  sign_in @admin
  request_id = @transport_request.id
  package_item_ids = @transport_request.package_items.pluck(:id)

  assert_difference('TransportRequest.count', -1) do
    assert_difference('PackageItem.count', -@transport_request.package_items.count) do
      delete admin_transport_request_url(@transport_request)
    end
  end

  assert_not TransportRequest.exists?(request_id)
  package_item_ids.each do |id|
    assert_not PackageItem.exists?(id)
  end
  assert_redirected_to admin_transport_requests_path
end

test "update with invalid data re-renders edit" do
  sign_in @admin

  patch admin_transport_request_url(@transport_request), params: {
    transport_request: {
      start_address: ''  # Invalid - required field
    }
  }

  assert_response :unprocessable_entity
  assert_template :edit
  request = assigns(:transport_request)
  assert_includes request.errors[:start_address], "can't be blank"
end
```

---

## Step 10: Run Tests and Debug

### Run Tests

```bash
# Run all controller tests
rails test test/controllers/admin/transport_requests_controller_test.rb

# Run specific test
rails test test/controllers/admin/transport_requests_controller_test.rb -n test_create_with_packages_mode_and_nested_package_items

# Run with verbose output
rails test test/controllers/admin/transport_requests_controller_test.rb --verbose
```

### Common Errors and Fixes

#### Error: `undefined method 'sign_in'`

**Cause:** Missing Devise test helpers.

**Fix:** Add to `test/test_helper.rb`:
```ruby
class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
```

#### Error: `undefined method 'assigns'`

**Cause:** Missing `rails-controller-testing` gem.

**Fix:** Add to `Gemfile` and run `bundle install`:
```ruby
group :test do
  gem "rails-controller-testing"
end
```

#### Error: Geocoder making real API calls

**Cause:** Geocoder not stubbed.

**Fix:** Add to `setup` block:
```ruby
setup do
  Geocoder.configure(lookup: :test, ip_lookup: :test)
  Geocoder::Lookup::Test.add_stub("Berlin, Germany", [...])
end

teardown do
  Geocoder::Lookup::Test.reset
end
```

#### Error: Duplicate records created

**Cause:** Controller processing params twice (e.g., in `assign_attributes` and `update`).

**Fix:** Exclude nested attributes from preliminary assignments:
```ruby
# Before (bug):
@record.assign_attributes(record_params)  # Processes nested attributes
@record.update(record_params)  # Processes again - duplicates!

# After (fixed):
@record.assign_attributes(record_params.except(:nested_attributes))
@record.update(record_params)
```

---

## Step 11: Verify Coverage

Ensure you've covered:

- ✅ All RESTful actions (index, show, new, create, edit, update, destroy)
- ✅ All custom actions (run_matching, cancel, etc.)
- ✅ Authentication (unauthenticated redirects to login)
- ✅ Authorization (wrong roles denied access)
- ✅ Happy paths (valid data creates/updates records)
- ✅ Sad paths (invalid data shows errors)
- ✅ All modes/variants (packages, loading_meters, vehicle_booking)
- ✅ Nested attributes (create, update, destroy via _destroy)
- ✅ Strong parameters (permitted attributes only)
- ✅ Geocoding/external services (stubbed)
- ✅ Background jobs (enqueued correctly)
- ✅ Redirects and flash messages
- ✅ Status transitions
- ✅ Edge cases

---

## Complete Test File Structure

```ruby
require "test_helper"

class Admin::TransportRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Stub external services
    # Load fixtures
  end

  teardown do
    # Reset stubs
  end

  # ========== AUTHENTICATION & AUTHORIZATION (6 tests) ==========
  test "should require authentication for index"
  test "should allow admin access"
  test "should allow dispatcher access"
  test "should deny customer access to index"
  test "should deny customer access to create"
  test "should deny customer access to update"

  # ========== INDEX ACTION (2 tests) ==========
  test "index lists all transport requests"
  test "index orders by created_at desc"

  # ========== SHOW ACTION (2 tests) ==========
  test "show displays transport request"
  test "show loads carrier requests"

  # ========== NEW ACTION (1 test) ==========
  test "new renders form"

  # ========== CREATE ACTION - PACKAGES MODE (4 tests) ==========
  test "create with packages mode and nested package_items"
  test "create with packages mode geocodes addresses"
  test "create with packages mode requires package_items"
  test "create with packages mode preserves data on validation error"

  # ========== CREATE ACTION - LOADING METERS MODE (3 tests) ==========
  test "create with loading_meters mode"
  test "create with loading_meters validates max 13.6"
  test "create with loading_meters requires loading_meters field"

  # ========== CREATE ACTION - VEHICLE BOOKING MODE (2 tests) ==========
  test "create with vehicle_booking mode"
  test "create with vehicle_booking validates vehicle_type"

  # ========== EDIT ACTION (1 test) ==========
  test "edit loads existing request with package_items"

  # ========== UPDATE ACTION (6 tests) ==========
  test "update changes addresses and geocodes"
  test "update adds new package_items"
  test "update removes package_items via _destroy"
  test "update modifies existing package_item"
  test "update changes dates"
  test "update preserves data on validation error"

  # ========== DESTROY ACTION (2 tests) ==========
  test "destroy removes transport_request"
  test "destroy removes transport_request and dependencies"

  # ========== RUN MATCHING ACTION (2 tests) ==========
  test "run_matching starts job for new request"
  test "run_matching rejects non-new requests"

  # ========== CANCEL ACTION (1 test) ==========
  test "cancel updates status to cancelled"

  # ========== STRONG PARAMETERS (4 tests) ==========
  test "create permits shipping_mode"
  test "create permits loading_meters fields"
  test "create permits package_items_attributes with _destroy"
  test "create filters unpermitted attributes"

  # ========== EDGE CASES (3 tests) ==========
  test "switching modes on update clears package_items"
  test "destroy removes transport_request and dependencies"
  test "update with invalid data re-renders edit"
end
```

**Total: 39 tests**

---

## Best Practices

### 1. Use Descriptive Test Names

```ruby
# Good
test "create with packages mode and nested package_items"

# Bad
test "test create"
```

### 2. Use `assert_difference` for Count Changes

```ruby
# Good
assert_difference('TransportRequest.count', 1) do
  post admin_transport_requests_url, params: { ... }
end

# Bad
count_before = TransportRequest.count
post admin_transport_requests_url, params: { ... }
assert_equal count_before + 1, TransportRequest.count
```

### 3. Stub External Services

Always stub APIs, geocoding, payment gateways, etc.:

```ruby
setup do
  Geocoder.configure(lookup: :test)
  Geocoder::Lookup::Test.add_stub("Address", [...])
end
```

### 4. Test Both Success and Failure Paths

```ruby
test "create with valid data succeeds"
test "create with invalid data fails and shows errors"
```

### 5. Reload Records After Updates

```ruby
patch admin_transport_request_url(@transport_request), params: { ... }
@transport_request.reload  # Important!
assert_equal 'new_value', @transport_request.field
```

### 6. Test Flash Messages

```ruby
post cancel_admin_transport_request_url(@transport_request)
assert_equal "Transport request was cancelled.", flash[:notice]
```

### 7. Group Related Tests

Use comment sections to organize by action or concern.

### 8. Keep Setup/Teardown Minimal

Only include what's needed for all tests. Move specific setup to individual tests.

---

## Common Patterns

### Testing Background Jobs

```ruby
test "action enqueues background job" do
  assert_enqueued_with(job: MatchCarriersJob, args: [@transport_request.id]) do
    post run_matching_admin_transport_request_url(@transport_request)
  end
end
```

### Testing Redirects

```ruby
post admin_transport_requests_url, params: { ... }
assert_redirected_to admin_transport_request_path(TransportRequest.last)
```

### Testing Status Codes

```ruby
get admin_transport_requests_url
assert_response :success  # 200

get new_admin_transport_request_url
assert_response :unauthorized  # 401

post admin_transport_requests_url, params: { invalid }
assert_response :unprocessable_entity  # 422
```

### Testing Assigned Instance Variables

```ruby
get admin_transport_request_url(@transport_request)
assert_equal @transport_request, assigns(:transport_request)
assert_not_nil assigns(:carrier_requests)
```

### Testing Templates

```ruby
post admin_transport_requests_url, params: { invalid }
assert_template :new
```

---

## Reference: Complete Example

See `test/controllers/admin/transport_requests_controller_test.rb` for a complete, working example with:
- 39 tests covering all functionality
- Multi-mode support (packages, loading_meters, vehicle_booking)
- Nested attributes (create, update, destroy)
- Authentication and authorization
- Geocoding stubs
- Background job enqueueing
- Edge cases and error handling

---

## Related Files

### Test Files
- `test/controllers/admin/transport_requests_controller_test.rb` - Full implementation (39 tests)
- `test/test_helper.rb` - Test configuration with Devise helpers
- `test/fixtures/` - Fixture data for tests

### Source Files
- `app/controllers/admin/transport_requests_controller.rb` - Controller under test
- `app/controllers/application_controller.rb` - Authorization helpers
- `app/models/transport_request.rb` - Model with validations and nested attributes
- `app/models/package_item.rb` - Nested model
- `app/models/user.rb` - User roles

### Configuration
- `Gemfile` - Test dependencies (`rails-controller-testing`)
- `config/routes.rb` - Route definitions for testing

---

## Checklist

Before marking controller tests complete:

- [ ] All RESTful actions tested (index, show, new, create, edit, update, destroy)
- [ ] All custom actions tested
- [ ] Authentication tested (unauthenticated users redirected)
- [ ] Authorization tested (wrong roles denied)
- [ ] All modes/variants tested (if applicable)
- [ ] Nested attributes tested (create, update, destroy)
- [ ] Strong parameters tested
- [ ] External services stubbed (no real API calls)
- [ ] Background jobs tested (enqueued correctly)
- [ ] Success paths tested (valid data)
- [ ] Failure paths tested (invalid data, error messages)
- [ ] Edge cases tested
- [ ] All tests passing with 0 failures, 0 errors
- [ ] Test file organized with clear section comments
- [ ] Descriptive test names
- [ ] No duplicate or redundant tests

---

**Last Review:** 2025-10-08
**Next Review Due:** 2025-11-08
