# Comprehensive Testing Implementation Plan

**Created:** 2025-10-08
**Status:** In Progress
**Priority:** High
**Related Docs:**
- [Project Architecture](../System/project_architecture.md)
- [Database Schema](../System/database_schema.md)
- [Multi-Mode Cargo Management SOP](../SOP/implementing_multi_mode_cargo_management.md)
- [Customer Cargo Management Implementation](./customer_cargo_management_implementation.md)

---

## Overview

Implement a comprehensive 3-tier testing strategy for the cargo management feature and general app functionality:

1. **Unit Tests** (Minitest - Programmatic)
2. **Integration Tests** (Controller + Database)
3. **E2E & Usability Tests** (MCP Chrome DevTools)

**Goal:** Achieve 100+ tests with full coverage of cargo management (packages, loading meters, vehicle booking) across admin and customer interfaces.

---

## Current Test Status

### Existing Test Structure
```
test/
├── models/               # Stub tests (need implementation)
│   ├── package_item_test.rb
│   ├── package_type_preset_test.rb
│   └── transport_request_test.rb
├── controllers/          # Basic route tests (need expansion)
│   └── admin/transport_requests_controller_test.rb
├── fixtures/             # Basic fixtures (need realistic data)
│   ├── package_items.yml
│   ├── package_type_presets.yml
│   └── transport_requests.yml
├── system/               # Empty (need E2E tests)
└── integration/          # Minimal (need workflow tests)
```

### What's Missing
- ❌ Comprehensive model validations tests
- ❌ Nested attributes tests
- ❌ Controller tests for all 3 cargo modes
- ❌ Customer controller tests
- ❌ System/E2E tests using MCP Chrome DevTools
- ❌ Performance profiling tests
- ❌ Accessibility tests
- ❌ Fixture data with realistic cargo scenarios

---

## Phase 1: Unit Tests (Minitest - Programmatic)

**Duration:** 2-3 hours
**Files to Create/Update:** 3 model test files, 3 fixture files

### 1.1 Model Tests

#### A) `test/models/package_item_test.rb` (15-20 tests)

**Tests to Implement:**
```ruby
# Associations
- belongs to transport_request with inverse_of
- inverse association works correctly

# Validations - Required Fields
- package_type presence
- quantity presence
- weight_kg presence

# Validations - Numericality
- quantity must be integer
- quantity must be > 0
- weight_kg must be > 0
- length_cm must be > 0 (if present)
- width_cm must be > 0 (if present)
- height_cm must be > 0 (if present)

# Edge Cases
- can save with nil dimensions (optional)
- cannot save with negative quantity
- cannot save with zero weight
- can save with decimal weight (9.99)

# Database Constraints
- references transport_request correctly
- foreign key constraint enforced
```

#### B) `test/models/transport_request_test.rb` (25-30 tests)

**Tests to Implement:**
```ruby
# Associations
- has_many package_items with dependent: :destroy
- has_many package_items with inverse_of
- accepts nested attributes for package_items
- allows destroy for nested attributes

# Validations - Shipping Mode
- shipping_mode must be in [packages, loading_meters, vehicle_booking]
- shipping_mode defaults to 'packages'
- invalid shipping_mode rejected

# Conditional Validations - Packages Mode
- requires at least one package_item when mode is 'packages'
- validates package_items presence
- allows empty package_items when mode is not 'packages'

# Conditional Validations - Loading Meters Mode
- requires loading_meters when mode is 'loading_meters'
- loading_meters must be > 0
- loading_meters must be <= 13.6
- requires total_height_cm when mode is 'loading_meters'
- total_height_cm must be > 0
- requires total_weight_kg when mode is 'loading_meters'
- total_weight_kg must be > 0

# Conditional Validations - Vehicle Booking Mode
- requires vehicle_type when mode is 'vehicle_booking'
- vehicle_type must be in VEHICLE_TYPES_BOOKING keys

# Nested Attributes Behavior
- can create with nested package_items
- can update with new package_items
- can destroy package_items via _destroy flag
- rejects all blank package_items

# Constants
- VEHICLE_TYPES_BOOKING exists and is frozen
- VEHICLE_TYPES_BOOKING contains 5 vehicle types
- Each vehicle type has name, max_weight, price_per_km

# Edge Cases
- switching modes clears irrelevant validations
- can save loading_meters mode without package_items
- can save vehicle_booking mode without loading_meters
```

#### C) `test/models/package_type_preset_test.rb` (5-10 tests)

**Tests to Implement:**
```ruby
# Validations
- name presence required
- name uniqueness enforced
- can save with nil dimensions (optional)

# Scopes
- default scope orders by display_order, name
- all returns records in correct order

# Methods
- as_json_defaults returns hash with dimension keys
- as_json_defaults handles nil values correctly
- as_json_defaults returns all 4 dimension fields
```

### 1.2 Fixture Updates

#### A) `test/fixtures/package_type_presets.yml`

**Update with 5 realistic presets:**
```yaml
euro_pallet:
  name: "Euro Pallet"
  default_length_cm: 120
  default_width_cm: 80
  default_height_cm: 144
  default_weight_kg: 300
  display_order: 1

industrial_pallet:
  name: "Industrial Pallet"
  default_length_cm: 120
  default_width_cm: 100
  default_height_cm: 144
  default_weight_kg: 400
  display_order: 2

half_pallet:
  name: "Half Pallet"
  default_length_cm: 60
  default_width_cm: 80
  default_height_cm: 144
  default_weight_kg: 150
  display_order: 3

quarter_pallet:
  name: "Quarter Pallet"
  default_length_cm: 60
  default_width_cm: 40
  default_height_cm: 144
  default_weight_kg: 75
  display_order: 4

custom_box:
  name: "Custom Box"
  default_length_cm: null
  default_width_cm: null
  default_height_cm: null
  default_weight_kg: null
  display_order: 5
```

#### B) `test/fixtures/transport_requests.yml`

**Add 3 requests covering all modes:**
```yaml
packages_mode:
  user: customer_one
  shipping_mode: packages
  start_address: "Berlin, Germany"
  destination_address: "Munich, Germany"
  status: new

loading_meters_mode:
  user: customer_one
  shipping_mode: loading_meters
  loading_meters: 13.6
  total_height_cm: 260
  total_weight_kg: 24000
  start_address: "Hamburg, Germany"
  destination_address: "Frankfurt, Germany"
  status: new

vehicle_booking_mode:
  user: customer_one
  shipping_mode: vehicle_booking
  vehicle_type: sprinter
  start_address: "Cologne, Germany"
  destination_address: "Stuttgart, Germany"
  status: new
```

#### C) `test/fixtures/package_items.yml`

**Add realistic package items:**
```yaml
euro_pallet_one:
  transport_request: packages_mode
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
```

#### D) `test/fixtures/users.yml`

**Add admin and customer users:**
```yaml
admin_user:
  email: admin@test.com
  encrypted_password: <%= Devise::Encryptor.digest(User, 'password123') %>
  role: admin
  company_name: Test Admin Company

customer_one:
  email: customer1@test.com
  encrypted_password: <%= Devise::Encryptor.digest(User, 'password123') %>
  role: customer
  company_name: Test Customer Company

customer_two:
  email: customer2@test.com
  encrypted_password: <%= Devise::Encryptor.digest(User, 'password123') %>
  role: customer
  company_name: Another Customer Company
```

---

## Phase 2: Integration Tests (Controller + DB)

**Duration:** 2-3 hours
**Files to Create/Update:** 2 controller test files, 1 integration test file

### 2.1 Admin Controller Tests

#### `test/controllers/admin/transport_requests_controller_test.rb`

**Tests to Implement (30-40 tests):**
```ruby
# Authentication & Authorization
- redirects to login if not authenticated
- allows access for admin users
- allows access for dispatcher users
- denies access for customer users

# Index Action
- lists all transport requests
- displays correct count
- includes package items count

# New Action
- renders form with nested fields
- form has shipping_mode tabs
- form includes package_items template

# Create Action - Packages Mode
- creates request with valid package_items
- saves nested package_items to database
- sets shipping_mode to 'packages'
- redirects to show page on success
- re-renders form on validation error
- preserves package_items data on error

# Create Action - Loading Meters Mode
- creates request with loading_meters
- validates loading_meters max 13.6
- requires total_height_cm and total_weight_kg
- does not create package_items

# Create Action - Vehicle Booking Mode
- creates request with vehicle_type
- validates vehicle_type in allowed list
- does not create package_items or loading_meters

# Edit Action
- loads existing request with package_items
- renders form with populated fields
- displays correct shipping_mode tab

# Update Action
- updates request attributes
- adds new package_items
- removes package_items via _destroy
- updates existing package_items
- preserves data on validation error

# Strong Parameters
- permits shipping_mode
- permits loading_meters, total_height_cm, total_weight_kg
- permits vehicle_type
- permits package_items_attributes with all fields
- permits _destroy in package_items_attributes
- rejects unpermitted parameters

# Edge Cases
- handles switching modes on update
- validates mode-specific fields correctly
- handles empty package_items array
- handles all package_items marked for destruction (should fail validation)
```

### 2.2 Customer Controller Tests

#### `test/controllers/customer/transport_requests_controller_test.rb`

**Tests to Implement (30-40 tests):**
```ruby
# Same as admin PLUS:

# Authorization - Scoping
- customer can only see own requests
- customer cannot see other customers' requests
- index scoped to current_user.transport_requests
- show raises 404 for other customers' requests
- edit raises 404 for other customers' requests
- update raises 404 for other customers' requests

# All CRUD operations
- Same as admin tests but with customer scope
- Same 3 mode tests (packages, loading_meters, vehicle_booking)
- Same nested attributes tests
- Same strong parameters tests
```

### 2.3 System Integration Test

#### `test/integration/cargo_management_flow_test.rb` (NEW FILE)

**Full workflow tests (10-15 tests):**
```ruby
# Admin Workflow
- login as admin
- navigate to new transport request
- select packages mode
- add 2 package items
- fill all required fields
- submit form
- verify redirect to show page
- verify package items saved
- navigate to edit
- add 1 more package item
- remove 1 existing package item
- submit
- verify changes persisted

# Customer Workflow
- login as customer
- create request with packages mode
- verify auto-quote generation (if applicable)
- edit request
- switch to loading_meters mode
- submit
- verify mode switched and package_items removed

# Mode Switching Workflow
- create request in packages mode
- edit and switch to loading_meters
- verify package_items cleared
- switch back to packages
- verify can add new package_items

# Nested Attributes Edge Cases
- create with 5 package items
- edit and mark 3 for destruction
- verify only 2 remain
- verify destroyed items deleted from database
```

---

## Phase 3: E2E & Usability Tests (MCP Chrome DevTools)

**Duration:** 3-4 hours
**Prerequisite:** Rails server running on `localhost:3000`

### 3.1 Setup

**Commands to run before testing:**
```bash
# Terminal 1: Start Rails server
rails server -p 3000

# Terminal 2: (if needed) Tailwind watcher
rails tailwindcss:watch

# Ensure test data exists
rails db:seed
```

**Test users to create:**
- Admin: admin@test.com / password123
- Customer: customer@test.com / password123

### 3.2 E2E Test Suite (14 Tests)

#### **Test 1: Admin Login & Navigation** (15 min)
**MCP Tools:** `navigate_page`, `take_snapshot`, `fill_form`, `list_console_messages`, `take_screenshot`

**Steps:**
1. Navigate to `/users/sign_in`
2. Take snapshot of login page
3. Fill email: admin@test.com, password: password123
4. Submit form
5. Verify redirect to dashboard
6. List console messages → assert 0 errors
7. Take screenshot of dashboard

**Success Criteria:**
- Login succeeds
- Redirects to `/admin` or `/admin/dashboard`
- Zero console errors

---

#### **Test 2: Admin - Create Transport Request (Packages Mode)** (30 min)
**MCP Tools:** All form interaction tools + `evaluate_script`

**Steps:**
1. Navigate to `/admin/transport_requests/new`
2. Take snapshot
3. Verify form elements present
4. Evaluate script: `document.querySelector('[data-controller="shipping-mode"]') !== null`
5. Evaluate script: `document.querySelector('[data-controller="package-items"]') !== null`
6. Click "Add Another Package" button
7. Evaluate script: count `.package-item` elements
8. Fill package fields (type, quantity, weight)
9. Fill address fields
10. Evaluate script: verify summary updates
11. Take screenshot
12. Submit form
13. List network requests → verify no errors
14. List console messages → assert 0 errors
15. Take screenshot of show page

**Success Criteria:**
- Form renders correctly
- Stimulus controllers connect
- Package items add dynamically
- Summary calculates correctly
- Form submits successfully
- Zero console errors

---

#### **Test 3: Tab Switching Behavior** (20 min)
**MCP Tools:** `take_snapshot`, `click`, `evaluate_script`

**Steps:**
1. Navigate to new form
2. Take initial snapshot → verify packages panel visible
3. Evaluate script: `document.querySelector('[data-mode="packages"]').classList.contains('hidden')` → false
4. Click "Lademeter" tab
5. Evaluate script: packages panel has `hidden` class → true
6. Evaluate script: loading_meters panel visible → true
7. Evaluate script: `document.querySelector('input[name*="shipping_mode"]').value` → "loading_meters"
8. Take screenshot
9. Click "Fahrzeugbuchung" tab
10. Repeat evaluations
11. List console messages → assert 0 errors

**Success Criteria:**
- Tabs switch correctly
- Only one panel visible at a time
- Hidden input updates
- No JavaScript errors

---

#### **Test 4: Package Type Preset Auto-fill** (15 min)
**MCP Tools:** `take_snapshot`, `fill`, `evaluate_script`

**Steps:**
1. Navigate to packages mode
2. Take snapshot
3. Evaluate script: verify presets data attribute is valid JSON
4. Select "Euro Pallet" from dropdown
5. Wait 500ms
6. Evaluate script: `document.querySelector('input[name*="length_cm"]').value` → "120"
7. Evaluate script: width_cm → "80"
8. Evaluate script: height_cm → "144"
9. Evaluate script: weight_kg → "300"
10. Take screenshot

**Success Criteria:**
- Preset data loads correctly
- Selecting preset auto-fills dimensions
- All 4 fields populate

---

#### **Test 5: Dynamic Package Add/Remove** (20 min)
**MCP Tools:** `click`, `evaluate_script`, `take_snapshot`

**Steps:**
1. Navigate to form
2. Evaluate script: count `.package-item` → should be 1 (default)
3. Click "Add Another Package" 3 times
4. Evaluate script: count `.package-item` → should be 4
5. Take snapshot
6. Click "Remove Package" on 2nd item
7. Evaluate script: 2nd item has `style="display: none"`
8. Evaluate script: 2nd item `_destroy` input value → "1"
9. Evaluate script: summary excludes removed item
10. Take screenshot

**Success Criteria:**
- Add creates new package items
- Remove hides item and sets _destroy flag
- Summary updates correctly

---

#### **Test 6: Loading Meters Mode** (15 min)
**MCP Tools:** `fill`, `evaluate_script`, `take_screenshot`

**Steps:**
1. Switch to loading meters tab
2. Fill loading_meters: 13.6
3. Fill total_height_cm: 260
4. Fill total_weight_kg: 24000
5. Evaluate script: `document.getElementById('lm-display').textContent` → "13.6"
6. Evaluate script: `document.getElementById('lm-weight-display').textContent` → "24000"
7. Take screenshot
8. Change loading_meters to 15.0
9. Submit form
10. Verify validation error appears
11. Take screenshot of error

**Success Criteria:**
- Live summary updates
- Max validation enforced (13.6m)
- Error displays correctly

---

#### **Test 7: Vehicle Booking Mode** (15 min)
**MCP Tools:** `take_snapshot`, `click`, `evaluate_script`

**Steps:**
1. Switch to vehicle booking tab
2. Take snapshot of vehicle grid
3. Click Sprinter radio button
4. Evaluate script: verify selected indicator visible
5. Evaluate script: `document.querySelector('input[name*="vehicle_type"]:checked').value` → "sprinter"
6. Take screenshot
7. Click LKW 7.5t
8. Verify selection updates
9. Evaluate script: verify price per km displays

**Success Criteria:**
- Vehicle grid renders
- Selection indicator works
- Hidden input updates
- Price displays correctly

---

#### **Test 8: Customer Interface (Green Theme)** (30 min)
**MCP Tools:** All tools, `evaluate_script` for theme verification

**Steps:**
1. Logout admin
2. Login as customer
3. Navigate to `/customer/transport_requests/new`
4. Take snapshot
5. Evaluate script: `document.querySelector('.border-green-600') !== null` → true
6. Evaluate script: `document.querySelector('.border-blue-600') === null` → true
7. Evaluate script: count green theme classes
8. Repeat packages mode test
9. Verify same functionality
10. Take screenshot
11. Compare with admin screenshot (theme should differ)

**Success Criteria:**
- Customer uses green theme
- No blue theme classes present
- Same functionality as admin

---

#### **Test 9: Edit Existing Request** (20 min)
**MCP Tools:** Standard interaction tools

**Steps:**
1. Create request via UI (packages mode with 2 items)
2. Navigate to edit page
3. Verify 2 package items display
4. Verify correct tab is active
5. Add 1 new package item
6. Remove 1 existing item
7. Submit
8. Navigate to show page
9. Verify 2 package items (1 original + 1 new)

**Success Criteria:**
- Existing items load correctly
- Can add new items
- Can remove existing items
- Changes persist

---

#### **Test 10: Form Validation & Error Handling** (20 min)
**MCP Tools:** `fill_form`, `take_snapshot`, `list_console_messages`

**Steps:**
1. Navigate to new form
2. Submit without filling fields
3. Take snapshot of error state
4. Verify error messages display
5. Switch to loading_meters mode
6. Fill only loading_meters
7. Submit
8. Verify conditional validation errors
9. List console messages → assert 0 errors
10. Take screenshot

**Success Criteria:**
- Validation errors display
- Conditional validations work
- No JavaScript errors
- Form data preserved

---

#### **Test 11: Performance Profiling** (30 min)
**MCP Tools:** `performance_start_trace`, `performance_stop_trace`, `performance_analyze_insight`

**Steps:**
1. Start performance trace
2. Navigate to new form
3. Fill all fields
4. Switch tabs 3 times
5. Add 3 package items
6. Submit form
7. Stop trace
8. Analyze insights:
   - FCP (First Contentful Paint)
   - LCP (Largest Contentful Paint)
   - CLS (Cumulative Layout Shift)
   - Long tasks
9. Take screenshot of metrics

**Success Criteria:**
- FCP < 2s
- LCP < 3s
- CLS ≤ 0.1
- No long tasks > 200ms

---

#### **Test 12: Network Throttling** (20 min)
**MCP Tools:** `emulate_network`, `emulate_cpu`

**Steps:**
1. Set network to "Fast 3G"
2. Set CPU throttling to 4x
3. Navigate to form
4. Take snapshot
5. Verify no FOUC
6. Verify Stimulus controllers connect
7. Perform form interaction
8. List console messages
9. Take screenshot

**Success Criteria:**
- No FOUC under throttling
- Controllers connect properly
- Form remains functional

---

#### **Test 13: Accessibility Quick Check** (15 min)
**MCP Tools:** `take_snapshot`, `evaluate_script`

**Steps:**
1. Take snapshot
2. Evaluate script: check all inputs have labels
3. Evaluate script: check form has proper structure
4. Verify tab buttons keyboard accessible
5. Check color contrast ratios
6. Take screenshot

**Success Criteria:**
- All inputs labeled
- Keyboard navigable
- Color contrast meets WCAG AA

---

#### **Test 14: Responsive Design Check** (15 min - if time)
**MCP Tools:** `resize_page`, `take_screenshot`

**Steps:**
1. Resize to mobile (375x667)
2. Take screenshot
3. Verify form remains usable
4. Resize to tablet (768x1024)
5. Take screenshot
6. Resize to desktop (1920x1080)
7. Take screenshot

**Success Criteria:**
- Form responsive across sizes
- No horizontal scroll
- Touch targets adequate

---

## Phase 4: Test Documentation & Reporting

**Duration:** 1 hour

### 4.1 Create Test Report

**File:** `test/reports/cargo_management_test_report.md`

**Structure:**
```markdown
# Cargo Management Test Report

**Date:** 2025-10-08
**Tested By:** Claude Code
**Rails Version:** 8.0
**Ruby Version:** 3.x

---

## Executive Summary

- Total Tests Run: XXX
- Passing: XXX
- Failing: XXX
- Skipped: XXX
- Coverage: XX%

---

## Unit Tests (Minitest)

### Models
- PackageItem: XX/XX passing
- TransportRequest: XX/XX passing
- PackageTypePreset: XX/XX passing

**Failures:**
[List any failures]

---

## Integration Tests

### Controllers
- Admin::TransportRequestsController: XX/XX passing
- Customer::TransportRequestsController: XX/XX passing

### Integration Flows
- Cargo Management Flow: XX/XX passing

**Failures:**
[List any failures]

---

## E2E Tests (MCP Chrome DevTools)

### Test Results Matrix

| Test | Status | Duration | Notes |
|------|--------|----------|-------|
| Admin Login | ✅ PASS | 2min | |
| Create Packages | ✅ PASS | 5min | |
| Tab Switching | ✅ PASS | 3min | |
| ... | | | |

### Screenshots

[Attach all screenshots with descriptions]

### Console Errors

[List any console errors found]

### Performance Metrics

- FCP: X.Xs
- LCP: X.Xs
- CLS: X.XX
- Long Tasks: X

---

## Known Issues

[List bugs discovered]

---

## Recommendations

[List improvements needed]
```

### 4.2 Update Documentation

**Update `.agent/README.md`:**
- Add test coverage badge/status
- Link to test report
- Update version history

---

## Execution Checklist

### Preparation
- [ ] Review testing plan
- [ ] Ensure Rails server can start
- [ ] Verify test database seeded
- [ ] Create test users (admin + customer)
- [ ] Verify Chrome DevTools MCP tools available

### Phase 1: Unit Tests
- [ ] Update fixtures with realistic data
- [ ] Implement PackageItem model tests
- [ ] Implement TransportRequest model tests
- [ ] Implement PackageTypePreset model tests
- [ ] Run `rails test test/models/`
- [ ] Fix any failures
- [ ] Achieve 100% passing

### Phase 2: Integration Tests
- [ ] Implement Admin controller tests
- [ ] Implement Customer controller tests
- [ ] Implement integration flow test
- [ ] Run `rails test test/controllers/`
- [ ] Run `rails test test/integration/`
- [ ] Fix any failures
- [ ] Achieve 100% passing

### Phase 3: E2E Tests
- [ ] Start Rails server
- [ ] Run Test 1: Login
- [ ] Run Test 2: Create Packages
- [ ] Run Test 3: Tab Switching
- [ ] Run Test 4: Preset Auto-fill
- [ ] Run Test 5: Add/Remove
- [ ] Run Test 6: Loading Meters
- [ ] Run Test 7: Vehicle Booking
- [ ] Run Test 8: Customer Theme
- [ ] Run Test 9: Edit Existing
- [ ] Run Test 10: Validation
- [ ] Run Test 11: Performance
- [ ] Run Test 12: Throttling
- [ ] Run Test 13: Accessibility
- [ ] Run Test 14: Responsive
- [ ] Document all findings

### Phase 4: Reporting
- [ ] Compile test report
- [ ] Organize screenshots
- [ ] Document known issues
- [ ] Update documentation
- [ ] Commit all test files
- [ ] Create PR if needed

---

## Success Criteria

✅ **Must Achieve:**
- 100+ unit tests passing
- 50+ integration tests passing
- 14 E2E tests passing
- Zero console errors
- Performance thresholds met
- Comprehensive report created

✅ **Nice to Have:**
- Test coverage > 80%
- All accessibility checks passing
- All responsive checks passing
- Automated test suite runnable in CI

---

## Estimated Timeline

| Phase | Duration | Cumulative |
|-------|----------|------------|
| Phase 1: Unit | 2-3 hrs | 2-3 hrs |
| Phase 2: Integration | 2-3 hrs | 4-6 hrs |
| Phase 3: E2E | 3-4 hrs | 7-10 hrs |
| Phase 4: Reporting | 1 hr | 8-11 hrs |

**Total: 8-11 hours**

---

## Next Steps After Testing

1. Fix all discovered bugs
2. Improve test coverage gaps
3. Set up CI/CD pipeline
4. Add automated screenshot comparison
5. Implement visual regression testing
6. Add load testing for performance
