# Customer Cargo Management Implementation Plan

**Created:** 2025-10-08
**Status:** In Progress
**Priority:** High
**Related Docs:** [Project Architecture](../System/project_architecture.md), [Database Schema](../System/database_schema.md), IMPLEMENTATION_GUIDE.md

---

## Overview

Complete the cargo management feature for the customer interface to achieve feature parity with the admin interface. Customers need the ability to specify cargo details (packages, loading meters, or vehicle booking) when creating transport requests.

---

## Current Status

### ✅ What's Complete (Admin Interface)
- Database migrations (shipping_mode, package_items, package_type_presets)
- Models configured (TransportRequest with nested attributes, PackageItem, PackageTypePreset)
- Stimulus controllers (shipping_mode_controller.js, package_items_controller.js)
- Admin partials created:
  - `_package_item_fields.html.erb`
  - `_packages_panel.html.erb`
  - `_loading_meters_panel.html.erb`
  - `_vehicle_booking_panel.html.erb`
  - `_datetime_section.html.erb`
- Admin form updated with 3-mode cargo management
- Admin controller permits package_items_attributes
- Seed data (5 package type presets)

### ❌ What's Missing (Customer Interface)
- No customer partials directory (`app/views/customer/transport_requests/partials/`)
- Customer form doesn't have cargo management sections
- Customer controller doesn't permit package_items_attributes
- Customers cannot specify packages, loading meters, or vehicle booking

---

## Why This Task Is Priority

1. **Feature Parity**: Admin has cargo management, customers don't (half-finished feature)
2. **Critical User Flow**: Customers need to specify cargo details when creating transport requests
3. **Low Risk**: All backend code exists, just needs customer UI adaptation
4. **Follows Project Philosophy**: "Make it work" (complete existing features before adding new ones)

---

## Implementation Plan

### Phase 1: Create Customer Partials Directory & Files

**Estimated Time:** 45 minutes

**Task**: Copy admin partials to customer directory with theme adjustments

**Directory to Create**: `app/views/customer/transport_requests/partials/`

**Files to Create** (copy from `app/views/admin/transport_requests/partials/`):

1. **`_package_item_fields.html.erb`**
   - Copy from admin version
   - Change color scheme: blue → green
   - No logic changes needed

2. **`_packages_panel.html.erb`**
   - Copy from admin version
   - Change color scheme: blue → green
   - Update data controller reference (already global)

3. **`_loading_meters_panel.html.erb`**
   - Copy from admin version
   - Change color scheme: blue → green
   - Update summary display styles

4. **`_vehicle_booking_panel.html.erb`**
   - Copy from admin version
   - Change color scheme: blue → green
   - Keep vehicle type pricing display

5. **`_datetime_section.html.erb`**
   - Copy from admin version
   - Change color scheme: blue → green
   - Keep 15-minute time select logic

**Color Class Replacements** (Find & Replace):
```
blue-600 → green-600
blue-500 → green-500
blue-50 → green-50
blue-200 → green-200
blue-300 → green-300
blue-400 → green-400
blue-700 → green-700
blue-800 → green-800
border-blue → border-green
text-blue → text-green
bg-blue → bg-green
ring-blue → ring-green
focus:ring-blue → focus:ring-green
```

**Additional Partials** (create if missing):
- `_pickup_address.html.erb` (check if exists, copy from admin if needed)
- `_delivery_address.html.erb` (check if exists, copy from admin if needed)

---

### Phase 2: Update Customer Form

**Estimated Time:** 30 minutes

**File**: `app/views/customer/transport_requests/_form.html.erb`

**Current Structure** (307 lines):
```erb
<%= form_with(model: [:customer, @transport_request]) do |f| %>
  <!-- Address sections (existing) -->
  <!-- Date/Time sections (existing) -->
  <!-- Cargo details (old simple version) -->
  <!-- Submit buttons -->
<% end %>
```

**New Structure** (add cargo management section):
```erb
<%= form_with(model: [:customer, @transport_request]) do |f| %>

  <!-- EXISTING: Address Sections -->
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
    <%= render 'customer/transport_requests/partials/pickup_address', f: f %>
    <%= render 'customer/transport_requests/partials/delivery_address', f: f %>
  </div>

  <!-- UPDATED: Date/Time Sections with 15-min increments -->
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
    <%= render 'customer/transport_requests/partials/datetime_section', f: f, field_prefix: 'pickup' %>
    <%= render 'customer/transport_requests/partials/datetime_section', f: f, field_prefix: 'delivery' %>
  </div>

  <!-- NEW: Cargo Management Section -->
  <div class="bg-white border border-gray-200 rounded-lg shadow-sm p-6"
       data-controller="shipping-mode"
       data-shipping-mode-default-mode-value="<%= @transport_request.shipping_mode || 'packages' %>">

    <h3 class="text-lg font-semibold text-gray-900 mb-4">Wie möchten Sie Ihre Ware versenden?</h3>

    <!-- Tabs -->
    <div class="border-b border-gray-200 mb-6">
      <nav class="flex space-x-8">
        <button type="button" data-mode="packages" data-action="shipping-mode#switch"
                data-shipping-mode-target="tab"
                class="py-4 px-1 border-b-2 font-medium text-sm transition">
          📦 Paletten & mehr
        </button>
        <button type="button" data-mode="loading_meters" data-action="shipping-mode#switch"
                data-shipping-mode-target="tab"
                class="py-4 px-1 border-b-2 font-medium text-sm transition">
          📏 Lademeter
        </button>
        <button type="button" data-mode="vehicle_booking" data-action="shipping-mode#switch"
                data-shipping-mode-target="tab"
                class="py-4 px-1 border-b-2 font-medium text-sm transition">
          🚚 Fahrzeugbuchung
        </button>
      </nav>
    </div>

    <%= f.hidden_field :shipping_mode, data: { shipping_mode_target: "modeInput" } %>

    <!-- Panel: Packages -->
    <div data-shipping-mode-target="panel" data-mode="packages" class="hidden">
      <%= render 'customer/transport_requests/partials/packages_panel', f: f %>
    </div>

    <!-- Panel: Loading Meters -->
    <div data-shipping-mode-target="panel" data-mode="loading_meters" class="hidden">
      <%= render 'customer/transport_requests/partials/loading_meters_panel', f: f %>
    </div>

    <!-- Panel: Vehicle Booking -->
    <div data-shipping-mode-target="panel" data-mode="vehicle_booking" class="hidden">
      <%= render 'customer/transport_requests/partials/vehicle_booking_panel', f: f %>
    </div>
  </div>

  <!-- Equipment Requirements (conditional on packages mode) -->
  <% if @transport_request.shipping_mode == 'packages' || @transport_request.shipping_mode.nil? %>
    <div class="bg-white border border-gray-200 rounded-lg shadow-sm p-6">
      <h3 class="text-lg font-semibold text-gray-900 mb-4">Equipment Requirements</h3>

      <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
        <div class="flex items-center">
          <%= f.check_box :requires_liftgate, class: "h-4 w-4 text-green-600 rounded" %>
          <%= f.label :requires_liftgate, "Liftgate", class: "ml-2 text-sm text-gray-700" %>
        </div>

        <div class="flex items-center">
          <%= f.check_box :requires_pallet_jack, class: "h-4 w-4 text-green-600 rounded" %>
          <%= f.label :requires_pallet_jack, "Pallet Jack", class: "ml-2 text-sm text-gray-700" %>
        </div>

        <div class="flex items-center">
          <%= f.check_box :requires_side_loading, class: "h-4 w-4 text-green-600 rounded" %>
          <%= f.label :requires_side_loading, "Side Loading", class: "ml-2 text-sm text-gray-700" %>
        </div>

        <div class="flex items-center">
          <%= f.check_box :requires_tarp, class: "h-4 w-4 text-green-600 rounded" %>
          <%= f.label :requires_tarp, "Tarp", class: "ml-2 text-gray-700" %>
        </div>

        <div class="flex items-center">
          <%= f.check_box :requires_gps_tracking, class: "h-4 w-4 text-green-600 rounded" %>
          <%= f.label :requires_gps_tracking, "GPS Tracking", class: "ml-2 text-gray-700" %>
        </div>
      </div>
    </div>
  <% end %>

  <!-- EXISTING: Submit Buttons -->
  <div class="flex justify-end space-x-4">
    <%= link_to "Cancel", customer_transport_requests_path,
        class: "px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50" %>
    <%= f.submit "Create Transport Request",
        class: "px-6 py-2 bg-green-600 text-white rounded-md hover:bg-green-700" %>
  </div>

<% end %>
```

---

### Phase 3: Update Customer Controller

**Estimated Time:** 10 minutes

**File**: `app/controllers/customer/transport_requests_controller.rb`

**Current `transport_request_params` method** (likely missing cargo params):
```ruby
def transport_request_params
  params.require(:transport_request).permit(
    :start_address, :start_latitude, :start_longitude, :start_country,
    :destination_address, :destination_latitude, :destination_longitude, :destination_country,
    :distance_km,
    :pickup_date_from, :pickup_date_to, :pickup_time_from, :pickup_time_to,
    :delivery_date_from, :delivery_date_to, :delivery_time_from, :delivery_time_to,
    :vehicle_type,
    :cargo_length_cm, :cargo_width_cm, :cargo_height_cm, :cargo_weight_kg,
    :requires_liftgate, :requires_pallet_jack, :requires_side_loading,
    :requires_tarp, :requires_gps_tracking,
    :driver_language
    # Missing shipping mode and package items!
  )
end
```

**Updated `transport_request_params` method**:
```ruby
def transport_request_params
  params.require(:transport_request).permit(
    # Existing address params
    :start_address, :start_latitude, :start_longitude, :start_country,
    :destination_address, :destination_latitude, :destination_longitude, :destination_country,
    :distance_km,

    # Existing date/time params
    :pickup_date_from, :pickup_date_to, :pickup_time_from, :pickup_time_to,
    :delivery_date_from, :delivery_date_to, :delivery_time_from, :delivery_time_to,

    # Existing cargo params
    :vehicle_type,
    :cargo_length_cm, :cargo_width_cm, :cargo_height_cm, :cargo_weight_kg,
    :requires_liftgate, :requires_pallet_jack, :requires_side_loading,
    :requires_tarp, :requires_gps_tracking,
    :driver_language,

    # NEW: Shipping mode params
    :shipping_mode,
    :loading_meters,
    :total_height_cm,
    :total_weight_kg,

    # NEW: Nested attributes for package items
    package_items_attributes: [
      :id,
      :package_type,
      :quantity,
      :length_cm,
      :width_cm,
      :height_cm,
      :weight_kg,
      :_destroy
    ]
  )
end
```

---

### Phase 4: Testing

**Estimated Time:** 30 minutes

**Manual Test Checklist**:

#### Packages Mode
- [ ] Customer can access new transport request form
- [ ] Default mode is "packages" (tab active)
- [ ] Can add package items dynamically (+ button works)
- [ ] Package type dropdown shows all 5 presets
- [ ] Selecting package type auto-fills dimensions from presets
- [ ] Changing quantity/weight updates summary display
- [ ] Can remove package items (- button works)
- [ ] Summary shows correct totals (quantity, weight)
- [ ] Form submits successfully with package items
- [ ] Package items saved to database (check in console or show page)

#### Loading Meters Mode
- [ ] Can switch to "Lademeter" tab
- [ ] Tab styling updates (active indicator)
- [ ] Can enter loading meters (0-13.6)
- [ ] Can enter total height (cm)
- [ ] Can enter total weight (kg)
- [ ] Summary updates live as values change
- [ ] Form submits with loading meter data
- [ ] Data persists (check in show page)

#### Vehicle Booking Mode
- [ ] Can switch to "Fahrzeugbuchung" tab
- [ ] All 5 vehicle types displayed (Sprinter, Sprinter XXL, LKW 7.5t, LKW 12t, LKW 40t)
- [ ] Can select vehicle type (radio button)
- [ ] Selection shows visual indicator (checkmark)
- [ ] Price per km displayed for each vehicle
- [ ] Distance estimate shown in note section
- [ ] Form submits with selected vehicle type
- [ ] Selection persists (check in show page)

#### DateTime Picker
- [ ] Pickup date field works
- [ ] Pickup time dropdown shows 15-minute increments (00:00, 00:15, 00:30, etc.)
- [ ] Delivery date field works
- [ ] Delivery time dropdown shows 15-minute increments
- [ ] Selected times persist after form submission

#### Equipment Requirements
- [ ] Equipment section visible in packages mode
- [ ] Equipment section hidden in loading meters mode
- [ ] Equipment section hidden in vehicle booking mode
- [ ] All checkboxes work (Liftgate, Pallet Jack, Side Loading, Tarp, GPS)
- [ ] Selections persist after form submission

#### Edit Flow
- [ ] Can edit existing transport request
- [ ] Correct shipping mode tab selected on load
- [ ] Package items load correctly in edit form
- [ ] Can edit package item quantities/weights
- [ ] Can add new package items in edit mode
- [ ] Can remove package items (sets _destroy flag)
- [ ] Update saves changes correctly

#### Validation
- [ ] Required fields validated (packages: type, quantity, weight)
- [ ] Required fields validated (loading meters: meters, height, weight)
- [ ] Required fields validated (vehicle booking: vehicle type selection)
- [ ] Error messages display properly
- [ ] Form retains values on validation error

---

### Phase 5: Documentation Update

**Estimated Time:** 10 minutes

**File**: `.agent/README.md`

**Changes**:

1. Update "Feature Implementation Status" section:
```markdown
### ✅ Completed Features

- **Transport Request Management**
  - Google Maps autocomplete for addresses
  - Detailed address fields (company, street, postal code, etc.)
  - Package items with type presets (admin & customer)
  - Loading meters mode (admin & customer)
  - Vehicle booking mode (admin & customer)
  - Date/time pickers with 15-min increments
```

2. Update "Customer Portal" section:
```markdown
- **Customer Portal**
  - Self-service transport request creation
  - Cargo management (packages, loading meters, vehicle booking)
  - Quote review and acceptance
  - Request status tracking
```

3. Mark IMPLEMENTATION_GUIDE.md as complete:
```markdown
- [x] Package item fields partial
- [x] Packages panel partial
- [x] Loading meters panel partial
- [x] Vehicle booking panel partial
- [x] Update main form
- [x] Update controller params
- [x] Copy to customer interface
- [x] Test all modes
- [x] Test form submission
- [x] Test edit flow
```

---

## Expected Deliverables

1. **5 customer partial files** (theme-adjusted copies from admin)
   - `_package_item_fields.html.erb`
   - `_packages_panel.html.erb`
   - `_loading_meters_panel.html.erb`
   - `_vehicle_booking_panel.html.erb`
   - `_datetime_section.html.erb`

2. **Updated customer form** (`_form.html.erb` with cargo sections)

3. **Updated customer controller** (`transport_requests_controller.rb` with params whitelist)

4. **Fully tested customer cargo workflow** (all 3 modes working)

5. **Updated documentation** (`.agent/README.md`)

---

## Risk Assessment

**Low Risk** because:
- ✅ All backend logic exists (models, migrations, associations, validations)
- ✅ Stimulus controllers are global (work for both admin and customer)
- ✅ No database changes needed (schema already supports cargo management)
- ✅ Proven pattern (copy-paste with theme adjustments from working admin code)
- ✅ Easy rollback (just revert files, no data loss)

**Potential Issues & Solutions**:

| Issue | Solution |
|-------|----------|
| Color class mismatches | Test in browser, adjust manually |
| Missing address partials | Create from scratch or copy from admin |
| Validation errors | Check `accepts_nested_attributes_for` in TransportRequest model |
| JS not working | Verify Stimulus controllers registered in `application.js` |
| Nested attributes not saving | Double-check controller permits `package_items_attributes` |

---

## Success Criteria

- [ ] Customer can create transport request with packages mode
- [ ] Customer can create transport request with loading meters mode
- [ ] Customer can create transport request with vehicle booking mode
- [ ] Customer can switch between modes during form fill
- [ ] Customer can edit existing transport request and modify cargo
- [ ] Package items persist correctly in database
- [ ] All 3 modes work without JavaScript errors
- [ ] Form validation works for all modes
- [ ] Customer interface matches admin functionality (feature parity achieved)

---

## Timeline

**Total Estimated Time**: 2 hours 5 minutes

| Phase | Duration | Tasks |
|-------|----------|-------|
| 1. Create Customer Partials | 45 min | Copy 5 files, mkdir, adjust colors |
| 2. Update Customer Form | 30 min | Add cargo sections to _form.html.erb |
| 3. Update Customer Controller | 10 min | Permit new params |
| 4. Testing | 30 min | Manual testing all 3 modes (checklist above) |
| 5. Documentation | 10 min | Update .agent/README.md |

---

## Next Steps After Completion

Once customer cargo management is complete, consider:

1. **Theme System Completion** (from THEME_STATUS.md)
   - Update hard-coded colors to use CSS variables
   - Fix avatar dropdown theme support
   - Add theme-aware component classes

2. **Performance Optimization** (from `.agent/Tasks/performance_optimization.md`)
   - Add missing database indexes
   - Fix N+1 queries
   - Implement caching strategy

3. **Automated Testing** (deferred per project philosophy)
   - RSpec for service objects (Pricing::Calculator, Matching::Algorithm)
   - Request specs for controllers
   - System tests for critical flows

---

## Related Documentation

- **[IMPLEMENTATION_GUIDE.md](../../IMPLEMENTATION_GUIDE.md)** - Original cargo management guide (admin)
- **[Project Architecture](../System/project_architecture.md)** - Tech stack and patterns
- **[Database Schema](../System/database_schema.md)** - PackageItem and TransportRequest schema
- **[.agent README](../README.md)** - Documentation index

---

## Version History

| Date | Change | Author |
|------|--------|--------|
| 2025-10-08 | Initial plan created | Claude Code |

---

**Status**: Ready to implement
**Next Action**: Create customer partials directory and copy files
