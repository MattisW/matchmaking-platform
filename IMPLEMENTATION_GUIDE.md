# Implementation Guide: Cargo Management & DateTime Picker

## Overview

This guide provides the complete implementation for the remaining form partials and controller updates needed to complete the cargo management feature.

## ✅ Already Completed

1. ✅ Database migrations (shipping_mode, package_items, package_type_presets)
2. ✅ Models (PackageItem, PackageTypePreset, TransportRequest)
3. ✅ Seed data (5 package type presets)
4. ✅ Stimulus controllers (shipping_mode_controller.js, package_items_controller.js)
5. ✅ Helper method (time_options_15min)
6. ✅ DateTime partial (partials/_datetime_section.html.erb)

## 📋 Remaining Implementation

### Step 1: Create Package Item Fields Partial

**File:** `app/views/admin/transport_requests/partials/_package_item_fields.html.erb`

```erb
<%# This partial is used for both new records (via template) and existing records %>
<% # For new records, Rails will use NEW_RECORD as the index which gets replaced by JS %>
<div class="package-item bg-gray-50 border border-gray-200 rounded-lg p-4 mb-4">
  <%= f.hidden_field :_destroy, data: { package_items_target: "destroy" } %>

  <div class="flex justify-between items-start mb-4">
    <h4 class="text-sm font-semibold text-gray-700">Package Item</h4>
    <button type="button"
            data-action="package-items#remove"
            class="text-red-600 hover:text-red-800 text-sm font-medium">
      − Remove Package
    </button>
  </div>

  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
    <!-- Package Type & Quantity -->
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">Package Type *</label>
      <%= f.select :package_type,
          options_for_select(
            PackageTypePreset.all.map { |p| [p.name, p.name.downcase.gsub(' ', '_')] },
            f.object.package_type
          ),
          { include_blank: "Select type" },
          data: { action: "change->package-items#typeChanged" },
          class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" %>
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">Quantity *</label>
      <%= f.number_field :quantity,
          min: 1,
          value: f.object.quantity || 1,
          data: { action: "change->package-items#updateSummary" },
          class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" %>
    </div>

    <!-- Dimensions -->
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">Length (cm)</label>
      <%= f.number_field :length_cm,
          min: 0,
          step: 1,
          placeholder: "120",
          class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" %>
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">Width (cm)</label>
      <%= f.number_field :width_cm,
          min: 0,
          step: 1,
          placeholder: "80",
          class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" %>
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">Height (cm)</label>
      <%= f.number_field :height_cm,
          min: 0,
          step: 1,
          placeholder: "144",
          class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" %>
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">Weight (kg) *</label>
      <%= f.number_field :weight_kg,
          min: 0,
          step: 0.01,
          placeholder: "300",
          data: { action: "change->package-items#updateSummary" },
          class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" %>
    </div>
  </div>
</div>
```

### Step 2: Create Packages Panel Partial

**File:** `app/views/admin/transport_requests/partials/_packages_panel.html.erb`

```erb
<div data-controller="package-items"
     data-package-items-presets-value='<%= PackageTypePreset.all.map { |p| [p.name.downcase.gsub(" ", "_"), p.as_json_defaults] }.to_h.to_json %>'>

  <h4 class="text-base font-semibold text-gray-900 mb-4">Package Details</h4>

  <div data-package-items-target="container">
    <%= f.fields_for :package_items do |package_form| %>
      <%= render 'admin/transport_requests/partials/package_item_fields', f: package_form %>
    <% end %>
  </div>

  <!-- Template for new package items -->
  <template data-package-items-target="template">
    <%= f.fields_for :package_items, PackageItem.new, child_index: 'NEW_RECORD' do |package_form| %>
      <%= render 'admin/transport_requests/partials/package_item_fields', f: package_form %>
    <% end %>
  </template>

  <!-- Add Button -->
  <button type="button"
          data-action="package-items#add"
          class="w-full mt-4 px-4 py-2 border-2 border-dashed border-blue-300 text-blue-600 rounded-md hover:border-blue-400 hover:bg-blue-50 transition">
    + Add Another Package
  </button>

  <!-- Summary -->
  <div class="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
    <h5 class="text-sm font-semibold text-gray-700 mb-2">Summary</h5>
    <div data-package-items-target="summary" class="text-sm text-gray-600">
      Packstück(e): <strong>0</strong> Gesamtgewicht: <strong>0.00kg</strong>
    </div>
  </div>
</div>
```

### Step 3: Create Loading Meters Panel Partial

**File:** `app/views/admin/transport_requests/partials/_loading_meters_panel.html.erb`

```erb
<div class="space-y-4">
  <h4 class="text-base font-semibold text-gray-900 mb-4">Loading Meter Details</h4>

  <p class="text-sm text-gray-600 mb-4">
    Enter the required loading meters and total dimensions for your shipment (max. 13.6m).
  </p>

  <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">
        Loading Meters * <span class="text-xs text-gray-500">(max 13.6m)</span>
      </label>
      <%= f.number_field :loading_meters,
          min: 0,
          max: 13.6,
          step: 0.1,
          placeholder: "13.6",
          class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" %>
      <p class="text-xs text-gray-500 mt-1">Maximum truck length</p>
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">
        Total Height (cm) *
      </label>
      <%= f.number_field :total_height_cm,
          min: 0,
          step: 1,
          placeholder: "260",
          class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" %>
      <p class="text-xs text-gray-500 mt-1">Total cargo height</p>
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">
        Total Weight (kg) *
      </label>
      <%= f.number_field :total_weight_kg,
          min: 0,
          step: 1,
          placeholder: "24000",
          class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" %>
      <p class="text-xs text-gray-500 mt-1">Total cargo weight</p>
    </div>
  </div>

  <div class="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
    <h5 class="text-sm font-semibold text-gray-700 mb-2">Summary</h5>
    <div class="text-sm text-gray-600">
      <p>Lademeter: <strong id="lm-display">0.0m</strong></p>
      <p>Gesamtgewicht: <strong id="lm-weight-display">0kg</strong></p>
    </div>
  </div>
</div>

<script>
  // Simple live update for loading meters summary
  document.addEventListener('DOMContentLoaded', function() {
    const lmInput = document.querySelector('input[name*="loading_meters"]');
    const weightInput = document.querySelector('input[name*="total_weight_kg"]');
    const lmDisplay = document.getElementById('lm-display');
    const weightDisplay = document.getElementById('lm-weight-display');

    if (lmInput && lmDisplay) {
      lmInput.addEventListener('input', function() {
        lmDisplay.textContent = parseFloat(this.value || 0).toFixed(1) + 'm';
      });
    }

    if (weightInput && weightDisplay) {
      weightInput.addEventListener('input', function() {
        weightDisplay.textContent = parseInt(this.value || 0) + 'kg';
      });
    }
  });
</script>
```

### Step 4: Create Vehicle Booking Panel Partial

**File:** `app/views/admin/transport_requests/partials/_vehicle_booking_panel.html.erb`

```erb
<div class="space-y-4">
  <h4 class="text-base font-semibold text-gray-900 mb-4">Vehicle Booking (Dedicated Vehicle)</h4>

  <p class="text-sm text-gray-600 mb-6">
    Select a dedicated vehicle type. The price is calculated based on distance (per km).
  </p>

  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
    <% TransportRequest::VEHICLE_TYPES_BOOKING.each do |key, vehicle| %>
      <label class="relative flex flex-col p-4 border-2 rounded-lg cursor-pointer hover:border-blue-500 transition
                    <%= 'border-blue-600 bg-blue-50' if f.object.vehicle_type == key %>">
        <%= f.radio_button :vehicle_type,
            key,
            class: "sr-only",
            data: { action: "change->shipping-mode#updateVehicleSelection" } %>

        <div class="flex flex-col items-center text-center">
          <!-- Vehicle Icon -->
          <div class="text-4xl mb-2">
            <% case key %>
            <% when 'sprinter' %>
              🚐
            <% when 'sprinter_xxl' %>
              🚐
            <% when 'lkw_7_5' %>
              🚚
            <% when 'lkw_12' %>
              🚛
            <% when 'lkw_40' %>
              🚛
            <% end %>
          </div>

          <h5 class="font-semibold text-gray-900"><%= vehicle[:name] %></h5>
          <p class="text-xs text-gray-500 mt-1">max. <%= number_to_human(vehicle[:max_weight], units: :number) %>kg</p>
          <p class="text-sm font-medium text-blue-600 mt-2">
            ab <%= number_to_currency(vehicle[:price_per_km], unit: '€', format: '%n %u') %> pro km
          </p>
        </div>

        <!-- Selected indicator -->
        <% if f.object.vehicle_type == key %>
          <div class="absolute top-2 right-2 w-5 h-5 bg-blue-600 rounded-full flex items-center justify-center">
            <svg class="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
            </svg>
          </div>
        <% end %>
      </label>
    <% end %>
  </div>

  <div class="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
    <h5 class="text-sm font-semibold text-gray-700 mb-2">Note</h5>
    <p class="text-sm text-gray-600">
      The final price will be calculated based on the total distance (approximately <%= @transport_request.distance_km || 0 %>km).
      The estimated cost will be shown after you select a vehicle and submit the form.
    </p>
  </div>
</div>
```

### Step 5: Update Main Form with Cargo Section

**File:** `app/views/admin/transport_requests/_form.html.erb`

Find the cargo details section and replace it with:

```erb
<%= form_with(model: [:admin, @transport_request], local: true, class: "space-y-6") do |f| %>

  <!-- EXISTING: Address Section (keep as-is) -->
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
    <%= render 'admin/transport_requests/partials/pickup_address', f: f %>
    <%= render 'admin/transport_requests/partials/delivery_address', f: f %>
  </div>

  <!-- UPDATED: Date/Time Section with 15-min time selects -->
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
    <%= render 'admin/transport_requests/partials/datetime_section', f: f, field_prefix: 'pickup' %>
    <%= render 'admin/transport_requests/partials/datetime_section', f: f, field_prefix: 'delivery' %>
  </div>

  <!-- NEW: Cargo/Shipping Mode Section -->
  <div class="bg-white border border-gray-200 rounded-lg shadow-sm p-6"
       data-controller="shipping-mode"
       data-shipping-mode-default-mode-value="<%= @transport_request.shipping_mode || 'packages' %>">

    <h3 class="text-lg font-semibold text-gray-900 mb-4">Wie möchten Sie Ihre Ware versenden?</h3>

    <!-- Tabs -->
    <div class="border-b border-gray-200 mb-6">
      <nav class="flex space-x-8">
        <button type="button"
                data-mode="packages"
                data-action="shipping-mode#switch"
                data-shipping-mode-target="tab"
                class="py-4 px-1 border-b-2 font-medium text-sm transition">
          📦 Paletten & mehr
        </button>
        <button type="button"
                data-mode="loading_meters"
                data-action="shipping-mode#switch"
                data-shipping-mode-target="tab"
                class="py-4 px-1 border-b-2 font-medium text-sm transition">
          📏 Lademeter
        </button>
        <button type="button"
                data-mode="vehicle_booking"
                data-action="shipping-mode#switch"
                data-shipping-mode-target="tab"
                class="py-4 px-1 border-b-2 font-medium text-sm transition">
          🚚 Fahrzeugbuchung
        </button>
      </nav>
    </div>

    <%= f.hidden_field :shipping_mode, data: { shipping_mode_target: "modeInput" } %>

    <!-- Panel: Paletten & mehr -->
    <div data-shipping-mode-target="panel" data-mode="packages" class="hidden">
      <%= render 'admin/transport_requests/partials/packages_panel', f: f %>
    </div>

    <!-- Panel: Lademeter -->
    <div data-shipping-mode-target="panel" data-mode="loading_meters" class="hidden">
      <%= render 'admin/transport_requests/partials/loading_meters_panel', f: f %>
    </div>

    <!-- Panel: Fahrzeugbuchung -->
    <div data-shipping-mode-target="panel" data-mode="vehicle_booking" class="hidden">
      <%= render 'admin/transport_requests/partials/vehicle_booking_panel', f: f %>
    </div>
  </div>

  <!-- EXISTING: Equipment Requirements (keep as-is if you have them) -->
  <% if @transport_request.shipping_mode == 'packages' || @transport_request.shipping_mode.nil? %>
    <div class="bg-white border border-gray-200 rounded-lg shadow-sm p-6">
      <h3 class="text-lg font-semibold text-gray-900 mb-4">Equipment Requirements</h3>

      <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
        <div class="flex items-center">
          <%= f.check_box :requires_liftgate, class: "h-4 w-4 text-blue-600 rounded" %>
          <%= f.label :requires_liftgate, "Liftgate", class: "ml-2 text-sm text-gray-700" %>
        </div>

        <div class="flex items-center">
          <%= f.check_box :requires_pallet_jack, class: "h-4 w-4 text-blue-600 rounded" %>
          <%= f.label :requires_pallet_jack, "Pallet Jack", class: "ml-2 text-sm text-gray-700" %>
        </div>

        <div class="flex items-center">
          <%= f.check_box :requires_side_loading, class: "h-4 w-4 text-blue-600 rounded" %>
          <%= f.label :requires_side_loading, "Side Loading", class: "ml-2 text-sm text-gray-700" %>
        </div>

        <div class="flex items-center">
          <%= f.check_box :requires_tarp, class: "h-4 w-4 text-blue-600 rounded" %>
          <%= f.label :requires_tarp, "Tarp", class: "ml-2 text-sm text-gray-700" %>
        </div>

        <div class="flex items-center">
          <%= f.check_box :requires_gps_tracking, class: "h-4 w-4 text-blue-600 rounded" %>
          <%= f.label :requires_gps_tracking, "GPS Tracking", class: "ml-2 text-sm text-gray-700" %>
        </div>
      </div>
    </div>
  <% end %>

  <!-- Submit buttons -->
  <div class="flex justify-end space-x-4">
    <%= link_to "Cancel", admin_transport_requests_path, class: "px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50" %>
    <%= f.submit class: "px-6 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700" %>
  </div>

<% end %>
```

### Step 6: Update Controller to Permit New Parameters

**File:** `app/controllers/admin/transport_requests_controller.rb`

Update the `transport_request_params` method:

```ruby
def transport_request_params
  params.require(:transport_request).permit(
    # Existing params
    :start_address, :start_latitude, :start_longitude, :start_country,
    :destination_address, :destination_latitude, :destination_longitude, :destination_country,
    :distance_km,
    :pickup_date_from, :pickup_date_to, :pickup_time_from, :pickup_time_to,
    :delivery_date_from, :delivery_date_to, :delivery_time_from, :delivery_time_to,
    :pickup_notes, :delivery_notes,
    :vehicle_type,
    :cargo_length_cm, :cargo_width_cm, :cargo_height_cm, :cargo_weight_kg,
    :requires_liftgate, :requires_pallet_jack, :requires_side_loading,
    :requires_tarp, :requires_gps_tracking,
    :driver_language,
    :status,

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

### Step 7: Copy Partials for Customer Interface ✅ COMPLETE

**Status:** ✅ All customer partials created with green theme

Created the same partials in `app/views/customer/transport_requests/partials/` with colors updated from `blue` to `green` to match the customer theme.

**Theme Changes Applied:**
- `blue-600` → `green-600`
- `blue-500` → `green-500`
- `blue-50` → `green-50`
- `blue-300` → `green-300`
- `blue-200` → `green-200`

**Files Created:**
- `app/views/customer/transport_requests/partials/_package_item_fields.html.erb`
- `app/views/customer/transport_requests/partials/_packages_panel.html.erb`
- `app/views/customer/transport_requests/partials/_loading_meters_panel.html.erb`
- `app/views/customer/transport_requests/partials/_vehicle_booking_panel.html.erb`
- `app/views/customer/transport_requests/partials/_datetime_section.html.erb`

**Files Updated:**
- `app/views/customer/transport_requests/_form.html.erb` (cargo section rewritten with tabs)
- `app/controllers/customer/transport_requests_controller.rb` (params updated)

## Testing Checklist

### 1. Test Packages Mode
- [ ] Can add package items dynamically
- [ ] Package type dropdown shows all presets
- [ ] Selecting package type auto-fills dimensions
- [ ] Changing quantity/weight updates summary
- [ ] Can remove package items
- [ ] Summary shows correct totals

### 2. Test Loading Meters Mode
- [ ] Can enter loading meters (max 13.6)
- [ ] Can enter total height and weight
- [ ] Summary updates live

### 3. Test Vehicle Booking Mode
- [ ] Can select vehicle type
- [ ] Selection is visually indicated
- [ ] Price per km is displayed

### 4. Test DateTime Picker
- [ ] Date field works
- [ ] Time dropdown shows 15-minute increments
- [ ] Selected time persists after form submission

### 5. Test Tab Switching
- [ ] Clicking tabs switches panels
- [ ] Only one panel visible at a time
- [ ] Hidden field updates with selected mode
- [ ] Tab styling updates correctly

### 6. Test Form Submission
- [ ] Form submits successfully
- [ ] Package items are saved to database
- [ ] Shipping mode is saved
- [ ] Can edit existing transport request
- [ ] Can delete package items via checkbox

## Common Issues & Solutions

### Issue: "No route matches"
**Solution:** Run `bin/rails routes | grep transport_request` to verify routes exist.

### Issue: Package items not saving
**Solution:** Check `transport_request_params` includes `package_items_attributes`.

### Issue: Tabs not switching
**Solution:** Check browser console for JavaScript errors. Verify Stimulus controller is connected.

### Issue: Presets not auto-filling
**Solution:** Check that `data-package-items-presets-value` is properly JSON-encoded.

### Issue: DateTime field not showing time options
**Solution:** Verify `time_options_15min` helper method exists in ApplicationHelper.

## Next Steps

1. Create all the partial files listed above
2. Update the main form
3. Update the controller
4. Test each mode
5. Apply the same changes to customer interface
6. Add validation error handling in forms

## File Locations Summary

```
app/
├── controllers/
│   └── admin/
│       └── transport_requests_controller.rb (UPDATE)
├── helpers/
│   └── application_helper.rb (ALREADY DONE)
├── javascript/
│   └── controllers/
│       ├── shipping_mode_controller.js (ALREADY DONE)
│       └── package_items_controller.js (ALREADY DONE)
├── models/
│   ├── package_item.rb (ALREADY DONE)
│   ├── package_type_preset.rb (ALREADY DONE)
│   └── transport_request.rb (ALREADY DONE)
└── views/
    └── admin/
        └── transport_requests/
            ├── _form.html.erb (UPDATE)
            └── partials/
                ├── _datetime_section.html.erb (ALREADY DONE)
                ├── _package_item_fields.html.erb (CREATE)
                ├── _packages_panel.html.erb (CREATE)
                ├── _loading_meters_panel.html.erb (CREATE)
                └── _vehicle_booking_panel.html.erb (CREATE)
```

## Complete Implementation Checklist

### Admin Interface
- [x] Database migrations
- [x] Models
- [x] Seed data
- [x] Stimulus controllers
- [x] Helper method
- [x] DateTime partial
- [x] Package item fields partial
- [x] Packages panel partial
- [x] Loading meters panel partial
- [x] Vehicle booking panel partial
- [x] Update main form
- [x] Update controller params

### Customer Interface
- [x] Package item fields partial (green theme)
- [x] Packages panel partial (green theme)
- [x] Loading meters panel partial (green theme)
- [x] Vehicle booking panel partial (green theme)
- [x] DateTime section partial (green theme)
- [x] Update customer form with cargo sections
- [x] Update customer controller params

### Testing (Manual)
- [ ] Test all modes (packages, loading meters, vehicle booking)
- [ ] Test form submission
- [ ] Test edit flow
- [ ] Test admin vs customer theme differences
- [ ] Test package type presets auto-fill
- [ ] Test dynamic package item add/remove
- [ ] Test nested attributes persistence
