# Complete Testing Coverage Implementation Plan

**Created:** 2025-10-08
**Status:** IN PROGRESS
**Goal:** Expand test coverage to include ALL controllers, system tests, and E2E validation

**Related Docs:**
- [Comprehensive Testing Implementation](./comprehensive_testing_implementation.md)
- [Implementing Controller Tests SOP](../SOP/implementing_controller_tests.md)
- [Comprehensive Testing Report](../Reports/comprehensive_testing_report.md)

---

## Current State

### ✅ Completed (Phases 1-2)
- **138 tests passing** (71 model + 67 controller)
- **387 assertions**
- **100% pass rate**
- Models: PackageItem, TransportRequest, PackageTypePreset
- Controllers: Admin::TransportRequestsController, Customer::TransportRequestsController

### ⚠️ Missing Coverage
- 6 controllers with only stub tests (19 errors)
- 0 system tests (UI/UX validation)
- 0 E2E tests (performance, console errors)
- 0 integration workflow tests

---

## Phase 3: Complete Controller Test Coverage

**Goal:** Add ~80 tests to cover all remaining controllers

### 3.1 Admin::CarriersController (25 tests)

**File:** `test/controllers/admin/carriers_controller_test.rb`

**Coverage:**
- Authentication & Authorization (3 tests)
  - Require authentication for index
  - Allow admin/dispatcher access
  - Deny customer access

- Index Action (3 tests)
  - List all carriers with includes
  - Order by created_at desc
  - Pagination working

- Show Action (4 tests)
  - Display carrier with associations
  - Calculate statistics (total_jobs, won_jobs, success_rate)
  - Calculate average rating
  - Load carrier_requests with pagination

- New Action (1 test)
  - Render form with new carrier

- Create Action (4 tests)
  - Create with valid data
  - Geocode address on create
  - Array fields (pickup_countries, delivery_countries)
  - Validation errors re-render form

- Edit Action (1 test)
  - Load existing carrier

- Update Action (4 tests)
  - Update basic fields
  - Update array fields
  - Re-geocode if address changed
  - Validation errors re-render form

- Destroy Action (2 tests)
  - Delete carrier
  - Cascade delete carrier_requests (or restrict if has requests)

- Strong Parameters (3 tests)
  - Permit array fields (pickup_countries, delivery_countries)
  - Permit boolean fields (has_transporter, has_lkw, blacklisted)
  - Filter unpermitted attributes

### 3.2 Admin::CarrierRequestsController (15 tests)

**File:** `test/controllers/admin/carrier_requests_controller_test.rb`

**Coverage:**
- Authentication & Authorization (3 tests)
  - Require authentication
  - Allow admin/dispatcher
  - Deny customer

- Index Action (2 tests)
  - List all carrier requests with includes
  - Pagination working

- Show Action (2 tests)
  - Display carrier request with associations

- Accept Action (4 tests)
  - Mark carrier_request as won
  - Reject other offers for same transport_request
  - Update transport_request status to matched
  - Enqueue acceptance/rejection emails

- Reject Action (2 tests)
  - Mark carrier_request as rejected
  - Enqueue rejection email

- Edge Cases (2 tests)
  - Transaction rollback on email error
  - Cannot accept already accepted offer

### 3.3 Admin::PricingRulesController (12 tests)

**File:** `test/controllers/admin/pricing_rules_controller_test.rb`

**Coverage:**
- Authentication & Authorization (3 tests)
- Index (2 tests): List pricing rules, ordering
- Show (1 test): Display single rule
- New/Create (3 tests): Create rule, validation
- Edit/Update (2 tests): Update rule, validation
- Destroy (1 test): Delete rule

### 3.4 DashboardController (Admin) (8 tests)

**File:** `test/controllers/dashboard_controller_test.rb`

**Coverage:**
- Authentication & Authorization (3 tests)
  - Require authentication
  - Allow admin/dispatcher only
  - Deny customer (redirect to customer dashboard)

- Index Action (5 tests)
  - Calculate total_requests correctly
  - Calculate active_requests (using scope)
  - Calculate total_carriers (active scope)
  - Calculate pending_offers (status=offered)
  - Load recent_requests (limit 10, ordered)

### 3.5 OffersController (Public) (10 tests)

**File:** `test/controllers/offers_controller_test.rb`

**Coverage:**
- No Authentication Required (2 tests)
  - Show action accessible without login
  - Submit offer accessible without login

- Show Action (2 tests)
  - Display offer form with carrier_request
  - Load transport_request and carrier associations

- Submit Offer Action (6 tests)
  - Submit with valid data (price, delivery_date, notes)
  - Update status to "offered"
  - Set response_date to current time
  - Validation error for missing price
  - Validation error for invalid delivery_date
  - Re-render show on validation error

### 3.6 Customer::CarrierRequestsController (10 tests)

**File:** `test/controllers/customer/carrier_requests_controller_test.rb`

**Coverage:**
- Authentication & Authorization (3 tests)
  - Require authentication
  - Allow customer only
  - Deny admin access

- Index Action (2 tests)
  - List offers for transport_request (scoped to user)
  - Only show offered/won/rejected (not new/sent)
  - Order by offered_price asc

- Accept Action (3 tests)
  - Accept offer and mark won
  - Reject other offers
  - Update transport_request status and matched_carrier_id
  - Enqueue emails

- Reject Action (2 tests)
  - Mark carrier_request as rejected
  - Enqueue rejection email

**Phase 3 Total: ~80 new tests**

---

## Phase 4: System Tests - UI/UX Validation

**Goal:** Add ~40 tests for complete user interface testing with Capybara

### 4.1 Admin Authentication & Navigation (5 tests)

**File:** `test/system/admin/authentication_test.rb`

```ruby
test "admin can login with valid credentials"
test "admin sees navigation menu with all sections"
test "admin can logout"
test "dispatcher can access admin area"
test "customer cannot access admin area"
```

### 4.2 Admin Carriers Management (10 tests)

**File:** `test/system/admin/carriers_test.rb`

```ruby
test "admin can view carriers list with pagination"
test "admin can view carrier details - Overview tab"
test "admin can view carrier details - Transport History tab"
test "admin can view carrier details - Coverage tab with map"
test "admin can view carrier details - Equipment tab"
test "admin can create new carrier with full form"
test "admin can edit carrier"
test "admin can delete carrier with confirmation dialog"
test "pickup/delivery countries array fields work correctly"
test "fleet capabilities checkboxes persist correctly"
```

**Key validations:**
- Tab switching (Stimulus tabs_controller)
- Map display on Coverage tab
- Array field inputs for countries
- Statistics calculation display
- Pagination links

### 4.3 Admin Transport Requests (10 tests)

**File:** `test/system/admin/transport_requests_test.rb`

```ruby
test "admin can create request - packages mode with nested items"
test "admin can add package items dynamically"
test "admin can remove package items dynamically"
test "admin can create request - loading meters mode"
test "admin can create request - vehicle booking mode"
test "switching modes clears previous mode data"
test "Google Maps autocomplete fills coordinates"
test "DateTime picker populates date fields"
test "admin can run matching and see status change"
test "admin can view and accept carrier offers"
```

**Key validations:**
- Stimulus shipping_mode_controller (mode switching)
- Stimulus package_items_controller (add/remove nested forms)
- Stimulus autocomplete_controller (Google Maps)
- Stimulus datetime_picker_controller (date/time selection)
- Form validation displays correctly
- Nested attributes persisting

### 4.4 Customer Authentication & Dashboard (5 tests)

**File:** `test/system/customer/dashboard_test.rb`

```ruby
test "customer can login"
test "customer sees their requests only on dashboard"
test "customer dashboard shows statistics correctly"
test "customer navigation menu displays correctly"
test "customer cannot access admin pages"
```

### 4.5 Customer Transport Request Workflow (10 tests)

**File:** `test/system/customer/transport_requests_test.rb`

```ruby
test "customer can create request - packages mode"
test "customer can create request - loading meters mode"
test "customer can create request - vehicle booking mode"
test "Google Maps autocomplete works in customer form"
test "nested package items work in customer form"
test "customer can view carrier offers ordered by price"
test "customer can accept carrier offer"
test "customer can reject carrier offer"
test "customer can cancel their request"
test "customer can edit their request"
```

**Key validations:**
- Customer layout displays correctly
- Quote generation happens automatically
- Scoped to current_user.transport_requests
- German locale messages display
- Detailed address fields working

**Phase 4 Total: ~40 new tests**

---

## Phase 5: E2E Tests with MCP Chrome DevTools

**Goal:** Add ~15 tests for performance, console errors, accessibility

### 5.1 Performance Metrics (9 tests)

**File:** `test/e2e/performance_test.rb`

**Login Page:**
```ruby
test "login page has no console errors"
test "login page FCP < 2 seconds"
test "login page CLS < 0.1"
```

**Admin Dashboard:**
```ruby
test "dashboard loads without console errors"
test "dashboard statistics render correctly"
test "dashboard recent requests table loads"
```

**Transport Request Form:**
```ruby
test "form multi-mode switching has no JS errors"
test "Google Maps loads without errors"
test "nested form add/remove has no errors"
```

**Tools used:**
- `mcp__chrome-devtools__navigate_page`
- `mcp__chrome-devtools__list_console_messages`
- `mcp__chrome-devtools__performance_start_trace`
- `mcp__chrome-devtools__performance_stop_trace`
- `mcp__chrome-devtools__performance_analyze_insight`

### 5.2 Accessibility Tests (6 tests)

**File:** `test/e2e/accessibility_test.rb`

```ruby
test "all forms have proper labels"
test "keyboard navigation works on critical forms"
test "color contrast meets WCAG AA"
test "error messages are associated with fields"
test "required fields marked with aria-required"
test "dynamic content updates announce to screen readers"
```

**Phase 5 Total: ~15 new tests**

---

## Phase 6: Integration Tests - Complete Workflows

**Goal:** Add ~20 tests for end-to-end user journeys

### 6.1 Complete User Workflows (12 tests)

**File:** `test/integration/complete_workflows_test.rb`

```ruby
test "admin workflow: create request → run matching → accept offer"
test "customer workflow: create request → view offers → accept offer"
test "carrier workflow: receive email → submit offer → get acceptance"
test "quote workflow: generate quote → customer accepts → status updates"
test "multi-customer workflow: requests remain scoped correctly"
test "offer rejection workflow: all parties notified correctly"
```

**Each test validates:**
- All status transitions
- All email deliveries
- All database updates
- All redirects and flash messages

### 6.2 Email Integration Tests (8 tests)

**File:** `test/integration/email_workflows_test.rb`

```ruby
test "CarrierMailer.invitation sends with correct link"
test "CarrierMailer.invitation contains transport details"
test "CarrierMailer.offer_accepted sends to correct carrier"
test "CarrierMailer.offer_accepted contains acceptance details"
test "CarrierMailer.offer_rejected sends to correct carrier"
test "CarrierMailer.offer_rejected contains rejection reason"
test "multiple emails enqueued when accepting offer"
test "email templates render without errors"
```

**Phase 6 Total: ~20 new tests**

---

## Testing Infrastructure Setup

### Dependencies

```ruby
# Gemfile - already installed
group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "rails-controller-testing"
end
```

### System Test Base Class

**File:** `test/application_system_test_case.rb`

```ruby
require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  # Helper to login as admin
  def login_as_admin
    visit new_user_session_path
    fill_in "Email", with: users(:admin_user).email
    fill_in "Password", with: "password"
    click_button "Log in"
    assert_text "Dashboard" # Verify login succeeded
  end

  # Helper to login as customer
  def login_as_customer
    visit new_user_session_path
    fill_in "Email", with: users(:customer_one).email
    fill_in "Password", with: "password"
    click_button "Log in"
    assert_text "Transport Requests" # Verify login succeeded
  end

  # Helper to wait for Stimulus controller
  def wait_for_stimulus(controller_name)
    assert_selector "[data-controller='#{controller_name}']"
  end
end
```

---

## Implementation Order

### Week 1: Controller Tests (Phase 3)

**Day 1-2:**
- Admin::CarriersController (25 tests)
- Admin::CarrierRequestsController (15 tests)

**Day 3:**
- Admin::PricingRulesController (12 tests)
- DashboardController (8 tests)

**Day 4:**
- OffersController (10 tests)
- Customer::CarrierRequestsController (10 tests)

**Deliverable:** 80 new controller tests, all passing

### Week 2: System Tests (Phase 4)

**Day 1:**
- Admin authentication & carriers (15 tests)

**Day 2:**
- Admin transport requests (10 tests)

**Day 3:**
- Customer workflows (15 tests)

**Deliverable:** 40 system tests with Stimulus validation

### Week 3: E2E & Integration (Phases 5-6)

**Day 1:**
- E2E performance tests (15 tests)

**Day 2:**
- Integration workflow tests (20 tests)

**Deliverable:** Complete test suite with 293 tests

---

## Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| **Total Tests** | 138 | 293 |
| **Controller Coverage** | 48% (2/6) | 100% (6/6) |
| **System Tests** | 0 | 40 |
| **E2E Tests** | 0 | 15 |
| **Integration Tests** | 0 | 20 |
| **Pass Rate** | 100% | 100% |
| **Execution Time** | 1.05s | <5s |

---

## Acceptance Criteria

✅ All 6 controllers have comprehensive tests
✅ All Stimulus controllers validated in browser
✅ Zero console errors across all pages
✅ Performance metrics: FCP < 2s, CLS < 0.1
✅ All user workflows tested end-to-end
✅ All mailers tested with real templates
✅ Accessibility: WCAG AA compliance on forms
✅ Test suite executes in < 5 seconds
✅ 100% pass rate maintained
✅ Complete SOP documentation updated

---

## Risk Mitigation

### Potential Issues

1. **Geocoder API in system tests**
   - Mitigation: Use same stubbing pattern as controller tests

2. **Google Maps in headless browser**
   - Mitigation: Stub or use test API key, verify fields populated

3. **Email delivery in integration tests**
   - Mitigation: Use ActionMailer::TestHelper, assert_enqueued_emails

4. **Slow system tests**
   - Mitigation: Run in parallel, use headless Chrome, optimize database setup

5. **Flaky E2E tests**
   - Mitigation: Proper waits, retry logic, clear test data between runs

---

## Documentation Updates

### Files to Update

1. **`.agent/README.md`**
   - Update test count in feature status
   - Add Phase 3-6 completion

2. **`.agent/Reports/comprehensive_testing_report.md`**
   - Add Phase 3-6 results
   - Update final metrics

3. **Create new SOP:** `.agent/SOP/implementing_system_tests.md`
   - Capybara patterns
   - Stimulus controller testing
   - JavaScript interaction testing

4. **Create new SOP:** `.agent/SOP/implementing_e2e_tests.md`
   - MCP Chrome DevTools usage
   - Performance testing
   - Accessibility testing

---

**Next Steps:** Begin Phase 3 - Admin::CarriersController tests
