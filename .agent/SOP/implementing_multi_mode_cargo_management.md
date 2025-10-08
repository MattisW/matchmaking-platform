# SOP: Implementing Multi-Mode Cargo Management

**Last Updated:** 2025-10-08
**Author:** Claude Code
**Related Docs:**
- [Project Architecture](../System/project_architecture.md)
- [Database Schema](../System/database_schema.md)
- [Adding Database Migrations](./adding_database_migrations.md)
- [Customer Cargo Management Implementation Plan](../Tasks/customer_cargo_management_implementation.md)

---

## Overview

This SOP documents the complete process for implementing a **multi-mode cargo management system** with three distinct modes: Packages, Loading Meters, and Vehicle Booking. This pattern was implemented for the Transport Request form and demonstrates Rails best practices for:

- **Nested attributes** (has_many relationships in forms)
- **Stimulus controllers** for dynamic UI switching
- **Tabbed interfaces** with conditional rendering
- **Theme consistency** across admin and customer interfaces
- **Partial reuse** with minimal duplication

**Use this SOP when:**
- Adding similar multi-mode interfaces to other features
- Implementing nested form fields with dynamic add/remove
- Creating role-specific UI variations (admin vs customer)
- Building complex forms with conditional sections

---

## Prerequisites

Before following this SOP, ensure:

- [ ] Database migrations are complete (models exist)
- [ ] Model associations are configured (`accepts_nested_attributes_for`)
- [ ] Seed data exists (if needed for dropdowns/presets)
- [ ] Basic form structure exists (address, datetime fields, etc.)
- [ ] Understanding of Stimulus.js basics

---

## Architecture Overview

### The Three Modes

```
┌─────────────────────────────────────────────────────┐
│          Cargo Management Interface                 │
├─────────────────────────────────────────────────────┤
│                                                     │
│  📦 Packages Mode                                   │
│  └─ Dynamic package items (nested forms)           │
│     └─ Type presets for auto-fill                  │
│     └─ Add/Remove functionality                    │
│     └─ Weight/quantity summary                     │
│                                                     │
│  📏 Loading Meters Mode                             │
│  └─ Simple numeric inputs                          │
│     └─ Max validation (13.6m)                      │
│     └─ Live summary display                        │
│                                                     │
│  🚚 Vehicle Booking Mode                            │
│  └─ Radio button grid                              │
│     └─ 5 vehicle types (Sprinter, LKW variants)   │
│     └─ Price per km display                        │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Technology Stack for This Feature

- **Rails nested attributes** for package items
- **Stimulus.js** for tab switching and dynamic forms
- **Tailwind CSS** for styling with theme variations
- **ERB partials** for component organization
- **Strong parameters** for security

---

## Step-by-Step Implementation

### Phase 1: Database Schema Setup

**Duration:** 30 minutes (if starting from scratch)

#### 1.1 Add Columns to Main Table

Create migration for the main model (e.g., `transport_requests`):

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_cargo_fields_to_transport_requests.rb
class AddCargoFieldsToTransportRequests < ActiveRecord::Migration[8.0]
  def change
    # Shipping mode selector
    add_column :transport_requests, :shipping_mode, :string, default: 'packages'

    # Loading meters fields
    add_column :transport_requests, :loading_meters, :decimal, precision: 4, scale: 1
    add_column :transport_requests, :total_height_cm, :integer
    add_column :transport_requests, :total_weight_kg, :integer

    # Vehicle booking keeps existing vehicle_type column
    # (already exists in most cases)

    # Add index for filtering by mode
    add_index :transport_requests, :shipping_mode
  end
end
```

#### 1.2 Create Nested Model Table

Create migration for nested items (e.g., `package_items`):

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_package_items.rb
class CreatePackageItems < ActiveRecord::Migration[8.0]
  def change
    create_table :package_items do |t|
      t.references :transport_request, null: false, foreign_key: true
      t.string :package_type
      t.integer :quantity, default: 1
      t.integer :length_cm
      t.integer :width_cm
      t.integer :height_cm
      t.decimal :weight_kg, precision: 10, scale: 2

      t.timestamps
    end

    add_index :package_items, :package_type
  end
end
```

#### 1.3 Create Presets Table (Optional)

If you need preset data for auto-fill:

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_package_type_presets.rb
class CreatePackageTypePresets < ActiveRecord::Migration[8.0]
  def change
    create_table :package_type_presets do |t|
      t.string :name, null: false
      t.integer :default_length_cm
      t.integer :default_width_cm
      t.integer :default_height_cm
      t.decimal :default_weight_kg, precision: 10, scale: 2
      t.integer :display_order, default: 0

      t.timestamps
    end

    add_index :package_type_presets, :name, unique: true
    add_index :package_type_presets, :display_order
  end
end
```

#### 1.4 Run Migrations

```bash
rails db:migrate
```

**⚠️ Critical:** Always check `db/schema.rb` after migration to verify:
- Foreign keys are present
- Indexes are created
- Default values are set correctly

---

### Phase 2: Model Configuration

**Duration:** 15 minutes

#### 2.1 Main Model Setup

```ruby
# app/models/transport_request.rb
class TransportRequest < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :package_items, dependent: :destroy, inverse_of: :transport_request

  # CRITICAL: Enable nested attributes
  accepts_nested_attributes_for :package_items,
                                allow_destroy: true,
                                reject_if: :all_blank

  # Validations
  validates :shipping_mode, inclusion: {
    in: %w[packages loading_meters vehicle_booking],
    message: "%{value} is not a valid shipping mode"
  }

  # Conditional validations by mode
  with_options if: -> { shipping_mode == 'packages' } do
    validates :package_items, presence: { message: "must have at least one package" }
  end

  with_options if: -> { shipping_mode == 'loading_meters' } do
    validates :loading_meters, presence: true,
              numericality: { greater_than: 0, less_than_or_equal_to: 13.6 }
    validates :total_height_cm, presence: true, numericality: { greater_than: 0 }
    validates :total_weight_kg, presence: true, numericality: { greater_than: 0 }
  end

  with_options if: -> { shipping_mode == 'vehicle_booking' } do
    validates :vehicle_type, presence: true
  end

  # Constants for vehicle booking
  VEHICLE_TYPES_BOOKING = {
    'sprinter' => { name: 'Sprinter', max_weight: 1500, price_per_km: 1.20 },
    'sprinter_xxl' => { name: 'Sprinter XXL', max_weight: 2000, price_per_km: 1.50 },
    'lkw_7_5' => { name: 'LKW 7.5t', max_weight: 7500, price_per_km: 2.00 },
    'lkw_12' => { name: 'LKW 12t', max_weight: 12000, price_per_km: 2.50 },
    'lkw_40' => { name: 'LKW 40t', max_weight: 40000, price_per_km: 3.50 }
  }.freeze
end
```

#### 2.2 Nested Model Setup

```ruby
# app/models/package_item.rb
class PackageItem < ApplicationRecord
  # CRITICAL: Inverse association for nested attributes
  belongs_to :transport_request, inverse_of: :package_items

  # Validations
  validates :package_type, presence: true
  validates :quantity, presence: true, numericality: {
    only_integer: true,
    greater_than: 0
  }
  validates :weight_kg, presence: true, numericality: {
    greater_than: 0
  }

  # Optional dimension validations
  validates :length_cm, :width_cm, :height_cm,
            numericality: { greater_than: 0, allow_nil: true }
end
```

#### 2.3 Preset Model Setup (Optional)

```ruby
# app/models/package_type_preset.rb
class PackageTypePreset < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  # Default scope for UI display order
  default_scope { order(:display_order, :name) }

  # Helper for JSON serialization (used in Stimulus data attributes)
  def as_json_defaults
    {
      length_cm: default_length_cm,
      width_cm: default_width_cm,
      height_cm: default_height_cm,
      weight_kg: default_weight_kg
    }
  end
end
```

#### 2.4 Seed Preset Data

```ruby
# db/seeds.rb
PackageTypePreset.find_or_create_by!(name: 'Euro Pallet') do |p|
  p.default_length_cm = 120
  p.default_width_cm = 80
  p.default_height_cm = 144
  p.default_weight_kg = 300
  p.display_order = 1
end

PackageTypePreset.find_or_create_by!(name: 'Industrial Pallet') do |p|
  p.default_length_cm = 120
  p.default_width_cm = 100
  p.default_height_cm = 144
  p.default_weight_kg = 400
  p.display_order = 2
end

PackageTypePreset.find_or_create_by!(name: 'Half Pallet') do |p|
  p.default_length_cm = 60
  p.default_width_cm = 80
  p.default_height_cm = 144
  p.default_weight_kg = 150
  p.display_order = 3
end

PackageTypePreset.find_or_create_by!(name: 'Quarter Pallet') do |p|
  p.default_length_cm = 60
  p.default_width_cm = 40
  p.default_height_cm = 144
  p.default_weight_kg = 75
  p.display_order = 4
end

PackageTypePreset.find_or_create_by!(name: 'Custom Box') do |p|
  p.default_length_cm = nil
  p.default_width_cm = nil
  p.default_height_cm = nil
  p.default_weight_kg = nil
  p.display_order = 5
end
```

Run seeds:
```bash
rails db:seed
```

---

### Phase 3: Stimulus Controllers

**Duration:** 30 minutes

#### 3.1 Shipping Mode Controller (Tab Switching)

```javascript
// app/javascript/controllers/shipping_mode_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel", "modeInput"]
  static values = {
    defaultMode: { type: String, default: "packages" }
  }

  connect() {
    // Set initial mode from data attribute or default
    const initialMode = this.defaultModeValue
    this.switch({ target: this.findTabByMode(initialMode) })
  }

  switch(event) {
    const clickedTab = event.target
    const mode = clickedTab.dataset.mode

    // Update tabs styling
    this.tabTargets.forEach(tab => {
      if (tab === clickedTab) {
        tab.classList.add("border-green-500", "text-green-600")
        tab.classList.remove("border-transparent", "text-gray-500")
      } else {
        tab.classList.remove("border-green-500", "text-green-600")
        tab.classList.add("border-transparent", "text-gray-500")
      }
    })

    // Update panels visibility
    this.panelTargets.forEach(panel => {
      if (panel.dataset.mode === mode) {
        panel.classList.remove("hidden")
      } else {
        panel.classList.add("hidden")
      }
    })

    // Update hidden input value for form submission
    if (this.hasModeInputTarget) {
      this.modeInputTarget.value = mode
    }
  }

  findTabByMode(mode) {
    return this.tabTargets.find(tab => tab.dataset.mode === mode)
  }
}
```

#### 3.2 Package Items Controller (Dynamic Nested Forms)

```javascript
// app/javascript/controllers/package_items_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template", "summary", "destroy"]
  static values = {
    presets: Object
  }

  connect() {
    // If no package items exist yet, add one by default
    if (this.containerTarget.children.length === 0) {
      this.add()
    }
    this.updateSummary()
  }

  add(event) {
    if (event) event.preventDefault()

    const content = this.templateTarget.innerHTML
    const timestamp = new Date().getTime()
    const newContent = content.replace(/NEW_RECORD/g, timestamp)

    this.containerTarget.insertAdjacentHTML('beforeend', newContent)
    this.updateSummary()
  }

  remove(event) {
    event.preventDefault()

    const item = event.target.closest('.package-item')

    // If item has an ID (existing record), mark for destruction
    const destroyInput = item.querySelector('input[name*="_destroy"]')
    if (destroyInput) {
      destroyInput.value = '1'
      item.style.display = 'none'
    } else {
      // New record, just remove from DOM
      item.remove()
    }

    this.updateSummary()
  }

  typeChanged(event) {
    const select = event.target
    const selectedType = select.value
    const item = select.closest('.package-item')

    if (selectedType && this.presetsValue[selectedType]) {
      const preset = this.presetsValue[selectedType]

      // Auto-fill dimension fields
      const fields = ['length_cm', 'width_cm', 'height_cm', 'weight_kg']
      fields.forEach(field => {
        const input = item.querySelector(`input[name*="${field}"]`)
        if (input && preset[field]) {
          input.value = preset[field]
        }
      })
    }

    this.updateSummary()
  }

  updateSummary() {
    const visibleItems = Array.from(
      this.containerTarget.querySelectorAll('.package-item')
    ).filter(item => item.style.display !== 'none')

    let totalQuantity = 0
    let totalWeight = 0

    visibleItems.forEach(item => {
      const quantity = parseFloat(
        item.querySelector('input[name*="quantity"]')?.value || 0
      )
      const weight = parseFloat(
        item.querySelector('input[name*="weight_kg"]')?.value || 0
      )

      totalQuantity += quantity
      totalWeight += quantity * weight
    })

    if (this.hasSummaryTarget) {
      this.summaryTarget.innerHTML = `
        Packstück(e): <strong>${totalQuantity}</strong>
        Gesamtgewicht: <strong>${totalWeight.toFixed(2)}kg</strong>
      `
    }
  }
}
```

**Register Controllers:**

```javascript
// app/javascript/controllers/index.js
import { application } from "./application"
import ShippingModeController from "./shipping_mode_controller"
import PackageItemsController from "./package_items_controller"

application.register("shipping-mode", ShippingModeController)
application.register("package-items", PackageItemsController)
```

---

### Phase 4: View Partials

**Duration:** 60 minutes

#### 4.1 Directory Structure

Create organized partial directories:

```
app/views/
├── admin/
│   └── transport_requests/
│       ├── _form.html.erb
│       └── partials/
│           ├── _packages_panel.html.erb
│           ├── _package_item_fields.html.erb
│           ├── _loading_meters_panel.html.erb
│           └── _vehicle_booking_panel.html.erb
└── customer/
    └── transport_requests/
        ├── _form.html.erb
        └── partials/
            ├── _packages_panel.html.erb
            ├── _package_item_fields.html.erb
            ├── _loading_meters_panel.html.erb
            └── _vehicle_booking_panel.html.erb
```

#### 4.2 Main Form Structure

```erb
<%# app/views/admin/transport_requests/_form.html.erb %>
<%= form_with(model: [:admin, @transport_request], local: true) do |f| %>

  <%# ... existing address and datetime sections ... %>

  <!-- Cargo Management Section with Tabs -->
  <div class="bg-white border border-gray-200 rounded-lg shadow-sm p-6"
       data-controller="shipping-mode"
       data-shipping-mode-default-mode-value="<%= @transport_request.shipping_mode || 'packages' %>">

    <h3 class="text-lg font-semibold text-gray-900 mb-4">
      Wie möchten Sie Ihre Ware versenden?
    </h3>

    <!-- Tab Navigation -->
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

    <%= f.hidden_field :shipping_mode,
        data: { shipping_mode_target: "modeInput" } %>

    <!-- Panel: Packages -->
    <div data-shipping-mode-target="panel"
         data-mode="packages"
         class="hidden">
      <%= render 'admin/transport_requests/partials/packages_panel', f: f %>
    </div>

    <!-- Panel: Loading Meters -->
    <div data-shipping-mode-target="panel"
         data-mode="loading_meters"
         class="hidden">
      <%= render 'admin/transport_requests/partials/loading_meters_panel', f: f %>
    </div>

    <!-- Panel: Vehicle Booking -->
    <div data-shipping-mode-target="panel"
         data-mode="vehicle_booking"
         class="hidden">
      <%= render 'admin/transport_requests/partials/vehicle_booking_panel', f: f %>
    </div>
  </div>

  <%# ... form actions ... %>
<% end %>
```

#### 4.3 Packages Panel Partial

```erb
<%# app/views/admin/transport_requests/partials/_packages_panel.html.erb %>
<div data-controller="package-items"
     data-package-items-presets-value='<%= PackageTypePreset.all.map { |p| [p.name.downcase.gsub(" ", "_"), p.as_json_defaults] }.to_h.to_json %>'>

  <h4 class="text-base font-semibold text-gray-900 mb-4">Package Details</h4>

  <!-- Container for existing and new package items -->
  <div data-package-items-target="container">
    <%= f.fields_for :package_items do |package_form| %>
      <%= render 'admin/transport_requests/partials/package_item_fields',
          f: package_form %>
    <% end %>
  </div>

  <!-- Template for new items (hidden) -->
  <template data-package-items-target="template">
    <%= f.fields_for :package_items, PackageItem.new,
        child_index: 'NEW_RECORD' do |package_form| %>
      <%= render 'admin/transport_requests/partials/package_item_fields',
          f: package_form %>
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

#### 4.4 Package Item Fields Partial

```erb
<%# app/views/admin/transport_requests/partials/_package_item_fields.html.erb %>
<div class="package-item bg-gray-50 border border-gray-200 rounded-lg p-4 mb-4">
  <%= f.hidden_field :_destroy %>

  <div class="flex justify-between items-start mb-4">
    <h4 class="text-sm font-semibold text-gray-700">Package Item</h4>
    <button type="button"
            data-action="package-items#remove"
            class="text-red-600 hover:text-red-800 text-sm font-medium">
      − Remove Package
    </button>
  </div>

  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
    <!-- Package Type -->
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">
        Package Type *
      </label>
      <%= f.select :package_type,
          options_for_select(
            PackageTypePreset.all.map { |p|
              [p.name, p.name.downcase.gsub(' ', '_')]
            },
            f.object.package_type
          ),
          { include_blank: "Select type" },
          data: { action: "change->package-items#typeChanged" },
          class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" %>
    </div>

    <!-- Quantity -->
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">
        Quantity *
      </label>
      <%= f.number_field :quantity,
          min: 1,
          value: f.object.quantity || 1,
          data: { action: "change->package-items#updateSummary" },
          class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" %>
    </div>

    <!-- Dimensions -->
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">
        Length (cm)
      </label>
      <%= f.number_field :length_cm,
          min: 0, step: 1, placeholder: "120",
          class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" %>
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">
        Width (cm)
      </label>
      <%= f.number_field :width_cm,
          min: 0, step: 1, placeholder: "80",
          class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" %>
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">
        Height (cm)
      </label>
      <%= f.number_field :height_cm,
          min: 0, step: 1, placeholder: "144",
          class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" %>
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">
        Weight (kg) *
      </label>
      <%= f.number_field :weight_kg,
          min: 0, step: 0.01, placeholder: "300",
          data: { action: "change->package-items#updateSummary" },
          class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" %>
    </div>
  </div>
</div>
```

#### 4.5 Loading Meters Panel Partial

```erb
<%# app/views/admin/transport_requests/partials/_loading_meters_panel.html.erb %>
<div class="space-y-4">
  <h4 class="text-base font-semibold text-gray-900 mb-4">
    Loading Meter Details
  </h4>

  <p class="text-sm text-gray-600 mb-4">
    Enter the required loading meters and total dimensions for your shipment (max. 13.6m).
  </p>

  <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">
        Loading Meters * <span class="text-xs text-gray-500">(max 13.6m)</span>
      </label>
      <%= f.number_field :loading_meters,
          min: 0, max: 13.6, step: 0.1, placeholder: "13.6",
          class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" %>
      <p class="text-xs text-gray-500 mt-1">Maximum truck length</p>
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">
        Total Height (cm) *
      </label>
      <%= f.number_field :total_height_cm,
          min: 0, step: 1, placeholder: "260",
          class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" %>
      <p class="text-xs text-gray-500 mt-1">Total cargo height</p>
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">
        Total Weight (kg) *
      </label>
      <%= f.number_field :total_weight_kg,
          min: 0, step: 1, placeholder: "24000",
          class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" %>
      <p class="text-xs text-gray-500 mt-1">Total cargo weight</p>
    </div>
  </div>

  <div class="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
    <h5 class="text-sm font-semibold text-gray-700 mb-2">Summary</h5>
    <div class="text-sm text-gray-600">
      <p>Lademeter: <strong><span id="lm-display">0.0</span>m</strong></p>
      <p>Gesamtgewicht: <strong><span id="lm-weight-display">0</span>kg</strong></p>
    </div>
  </div>
</div>

<script>
  document.addEventListener('DOMContentLoaded', function() {
    const lmInput = document.querySelector('input[name*="loading_meters"]');
    const weightInput = document.querySelector('input[name*="total_weight_kg"]');
    const lmDisplay = document.getElementById('lm-display');
    const weightDisplay = document.getElementById('lm-weight-display');

    if (lmInput && lmDisplay) {
      lmInput.addEventListener('input', function() {
        lmDisplay.textContent = parseFloat(this.value || 0).toFixed(1);
      });
    }

    if (weightInput && weightDisplay) {
      weightInput.addEventListener('input', function() {
        weightDisplay.textContent = parseInt(this.value || 0);
      });
    }
  });
</script>
```

#### 4.6 Vehicle Booking Panel Partial

```erb
<%# app/views/admin/transport_requests/partials/_vehicle_booking_panel.html.erb %>
<div class="space-y-4">
  <h4 class="text-base font-semibold text-gray-900 mb-4">
    Vehicle Booking (Dedicated Vehicle)
  </h4>

  <p class="text-sm text-gray-600 mb-6">
    Select a dedicated vehicle type. The price is calculated based on distance (per km).
  </p>

  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
    <% TransportRequest::VEHICLE_TYPES_BOOKING.each do |key, vehicle| %>
      <label class="relative flex flex-col p-4 border-2 rounded-lg cursor-pointer hover:border-blue-500 transition <%= 'border-blue-600 bg-blue-50' if f.object.vehicle_type == key %>">
        <%= f.radio_button :vehicle_type, key, class: "sr-only" %>

        <div class="flex flex-col items-center text-center">
          <!-- Vehicle Icon -->
          <div class="text-4xl mb-2">
            <% case key %>
            <% when 'sprinter' %> 🚐
            <% when 'sprinter_xxl' %> 🚐
            <% when 'lkw_7_5' %> 🚚
            <% when 'lkw_12' %> 🚛
            <% when 'lkw_40' %> 🚛
            <% end %>
          </div>

          <h5 class="font-semibold text-gray-900"><%= vehicle[:name] %></h5>
          <p class="text-xs text-gray-500 mt-1">
            max. <%= number_with_delimiter(vehicle[:max_weight]) %>kg
          </p>
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

---

### Phase 5: Controller Updates

**Duration:** 10 minutes

#### 5.1 Strong Parameters

Update the controller to permit new parameters:

```ruby
# app/controllers/admin/transport_requests_controller.rb
class Admin::TransportRequestsController < Admin::BaseController
  # ... existing code ...

  private

  def transport_request_params
    params.require(:transport_request).permit(
      # Existing params
      :start_address, :destination_address,
      :pickup_date_from, :delivery_date_from,
      # ... other existing params ...

      # NEW: Cargo management params
      :shipping_mode,
      :loading_meters,
      :total_height_cm,
      :total_weight_kg,
      :vehicle_type,

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
end
```

**⚠️ Critical:** The `:_destroy` parameter is required for deleting nested records.

---

### Phase 6: Theme Adaptation for Customer Interface

**Duration:** 30 minutes

#### 6.1 Copy Partials to Customer Directory

```bash
mkdir -p app/views/customer/transport_requests/partials
cp app/views/admin/transport_requests/partials/_*.html.erb \
   app/views/customer/transport_requests/partials/
```

#### 6.2 Theme Color Replacement

Use find & replace in customer partials:

| Admin Color (Blue) | Customer Color (Green) |
|--------------------|------------------------|
| `blue-600` | `green-600` |
| `blue-500` | `green-500` |
| `blue-50` | `green-50` |
| `blue-300` | `green-300` |
| `blue-200` | `green-200` |
| `border-blue-` | `border-green-` |
| `text-blue-` | `text-green-` |
| `bg-blue-` | `bg-green-` |
| `ring-blue-` | `ring-green-` |
| `focus:ring-blue-` | `focus:ring-green-` |

**Example:**
```erb
<%# Admin: %>
class="border-blue-600 bg-blue-50 text-blue-600"

<%# Customer: %>
class="border-green-600 bg-green-50 text-green-600"
```

#### 6.3 Update Partial Paths

In customer partials, change render paths:

```erb
<%# Admin: %>
<%= render 'admin/transport_requests/partials/package_item_fields', f: package_form %>

<%# Customer: %>
<%= render 'customer/transport_requests/partials/package_item_fields', f: package_form %>
```

#### 6.4 Update Customer Controller

```ruby
# app/controllers/customer/transport_requests_controller.rb
class Customer::TransportRequestsController < Customer::BaseController
  # ... existing code ...

  private

  def transport_request_params
    params.require(:transport_request).permit(
      # Existing params
      :start_address, :destination_address,
      # ... other existing params ...

      # NEW: Cargo management params (same as admin)
      :shipping_mode,
      :loading_meters,
      :total_height_cm,
      :total_weight_kg,
      :vehicle_type,
      package_items_attributes: [
        :id, :package_type, :quantity,
        :length_cm, :width_cm, :height_cm, :weight_kg,
        :_destroy
      ]
    )
  end
end
```

---

### Phase 7: Testing

**Duration:** 45 minutes

#### 7.1 Manual Testing Checklist

**Packages Mode:**
- [ ] Click "Paletten & mehr" tab
- [ ] Default package item appears on load
- [ ] Click "Add Another Package" creates new item
- [ ] Select package type from dropdown
- [ ] Selecting preset auto-fills dimensions
- [ ] Enter quantity and weight
- [ ] Summary updates with total quantity and weight
- [ ] Click "Remove Package" hides item
- [ ] Submit form and verify data saves to database
- [ ] Edit existing request and verify package items load
- [ ] Delete package item via remove button
- [ ] Submit and verify deletion persists

**Loading Meters Mode:**
- [ ] Click "Lademeter" tab
- [ ] Packages panel hides, loading meters panel shows
- [ ] Enter loading meters (test max 13.6 validation)
- [ ] Enter total height and weight
- [ ] Summary displays live updates
- [ ] Submit form and verify data saves
- [ ] Edit existing request and verify fields populate

**Vehicle Booking Mode:**
- [ ] Click "Fahrzeugbuchung" tab
- [ ] Loading meters panel hides, vehicle grid shows
- [ ] Click vehicle type radio button
- [ ] Visual selection indicator appears
- [ ] Price per km displays correctly
- [ ] Submit form and verify vehicle_type saves
- [ ] Edit existing request and verify selection persists

**Tab Switching:**
- [ ] Tabs change active styling correctly
- [ ] Only one panel visible at a time
- [ ] Hidden `shipping_mode` input updates
- [ ] Default mode (packages) activates on page load
- [ ] Selected mode persists after validation errors

**Admin vs Customer Theme:**
- [ ] Admin interface uses blue theme
- [ ] Customer interface uses green theme
- [ ] Focus rings match respective themes
- [ ] Buttons, borders, backgrounds match theme

#### 7.2 Database Verification

After submitting forms, check database:

```ruby
rails console

# Check transport request saved correctly
tr = TransportRequest.last
tr.shipping_mode  # => "packages", "loading_meters", or "vehicle_booking"

# Check nested package items
tr.package_items.count  # => number of packages
tr.package_items.first.package_type  # => "euro_pallet", etc.

# Check loading meters fields
tr.loading_meters  # => 13.6 (or nil if not in loading_meters mode)
tr.total_height_cm  # => 260 (or nil if not in loading_meters mode)

# Check vehicle booking
tr.vehicle_type  # => "sprinter", "lkw_7_5", etc. (or nil if not in vehicle_booking mode)
```

#### 7.3 Edge Cases

Test these scenarios:

- [ ] Submit form with no packages (should fail validation)
- [ ] Submit form with invalid loading meters (>13.6m)
- [ ] Switch modes without losing data (before submit)
- [ ] Edit request and add more package items
- [ ] Edit request and remove all package items (should fail validation)
- [ ] Form validation errors display correctly
- [ ] Browser back button after submission (data should persist)

---

## Common Pitfalls & Solutions

### Issue: "Unpermitted parameters: package_items_attributes"

**Cause:** Controller params don't include nested attributes.

**Solution:** Add to `transport_request_params`:
```ruby
package_items_attributes: [:id, :package_type, :quantity, ..., :_destroy]
```

---

### Issue: Package items not saving to database

**Cause:** Missing `inverse_of` in model association.

**Solution:** Update model:
```ruby
class PackageItem < ApplicationRecord
  belongs_to :transport_request, inverse_of: :package_items
end

class TransportRequest < ApplicationRecord
  has_many :package_items, dependent: :destroy, inverse_of: :transport_request
  accepts_nested_attributes_for :package_items, allow_destroy: true
end
```

---

### Issue: Tabs not switching

**Cause:** Stimulus controller not connected or JavaScript errors.

**Solution:**
1. Check browser console for errors
2. Verify `data-controller="shipping-mode"` exists on parent div
3. Verify importmap includes Stimulus
4. Check controller file naming matches registration

---

### Issue: "NEW_RECORD" appears in form

**Cause:** JavaScript not replacing template placeholder.

**Solution:**
1. Verify `child_index: 'NEW_RECORD'` in fields_for
2. Check JavaScript replace logic in package_items_controller.js
3. Ensure template is wrapped in `<template>` tag

---

### Issue: Presets not auto-filling

**Cause:** JSON data attribute malformed or JavaScript error.

**Solution:**
1. Check `data-package-items-presets-value` is valid JSON
2. Verify preset data exists in database (run `rails db:seed`)
3. Check `as_json_defaults` method returns correct hash
4. Inspect browser console for JSON parsing errors

---

### Issue: Package items disappear after validation error

**Cause:** Form doesn't re-render existing package items on validation failure.

**Solution:** Ensure controller action includes:
```ruby
def create
  @transport_request = TransportRequest.new(transport_request_params)
  if @transport_request.save
    redirect_to @transport_request, notice: 'Created successfully.'
  else
    render :new, status: :unprocessable_entity  # <-- CRITICAL
  end
end
```

---

### Issue: Deleted items reappear after edit

**Cause:** `_destroy` flag not properly handled.

**Solution:**
1. Verify hidden field `<%= f.hidden_field :_destroy %>`
2. Check controller permits `:_destroy` parameter
3. Use `allow_destroy: true` in `accepts_nested_attributes_for`

---

## Best Practices

### 1. Keep Stimulus Controllers Generic

Stimulus controllers should work across admin and customer interfaces without modification. Avoid hardcoding role-specific logic.

**✅ Good:**
```javascript
// Works for both admin and customer
tab.classList.add("border-primary-500")
```

**❌ Bad:**
```javascript
// Hardcoded for admin
tab.classList.add("border-blue-500")
```

### 2. Use Partials for Reusability

Extract repeated UI patterns into partials. Adjust only theme colors when copying to customer views.

### 3. Validate by Mode

Use conditional validations based on `shipping_mode` to ensure correct data is present:

```ruby
with_options if: -> { shipping_mode == 'packages' } do
  validates :package_items, presence: true
end
```

### 4. Provide Clear Visual Feedback

- Active tab should be obviously different from inactive tabs
- Selected vehicle type should show clear indicator
- Summary fields should update immediately on input change

### 5. Test Nested Forms Thoroughly

Nested forms are complex. Test:
- Creating new records
- Editing existing records
- Deleting records (via `_destroy`)
- Validation errors (data should persist)

---

## Performance Considerations

### Lazy Load Presets

If you have many presets, consider loading them via AJAX instead of inline JSON:

```javascript
async loadPresets() {
  const response = await fetch('/api/package_type_presets.json')
  this.presetsValue = await response.json()
}
```

### Limit Package Items

Consider a reasonable limit on package items (e.g., 50) to prevent form performance issues:

```ruby
validates :package_items, length: { maximum: 50 }
```

### Use Indexes

Ensure database indexes exist for frequently queried fields:

```ruby
add_index :transport_requests, :shipping_mode
add_index :package_items, :package_type
```

---

## Checklist: Feature Complete

- [ ] Database migrations run successfully
- [ ] Models have correct associations and validations
- [ ] Seed data exists for presets
- [ ] Stimulus controllers registered and working
- [ ] Admin partials created and functional
- [ ] Customer partials created with correct theme
- [ ] Controllers permit all necessary parameters
- [ ] Forms submit and save data correctly
- [ ] Edit flow loads existing data
- [ ] Delete flow removes nested items
- [ ] All three modes tested manually
- [ ] Theme colors match role (blue=admin, green=customer)
- [ ] Summary calculations display correctly
- [ ] Validation errors handled gracefully
- [ ] Browser console has no JavaScript errors
- [ ] Documentation updated (this SOP!)

---

## Related Files

### Models
- `app/models/transport_request.rb`
- `app/models/package_item.rb`
- `app/models/package_type_preset.rb`

### Controllers
- `app/controllers/admin/transport_requests_controller.rb`
- `app/controllers/customer/transport_requests_controller.rb`

### Views
- `app/views/admin/transport_requests/_form.html.erb`
- `app/views/admin/transport_requests/partials/*`
- `app/views/customer/transport_requests/_form.html.erb`
- `app/views/customer/transport_requests/partials/*`

### JavaScript
- `app/javascript/controllers/shipping_mode_controller.js`
- `app/javascript/controllers/package_items_controller.js`

### Migrations
- `db/migrate/*_add_cargo_fields_to_transport_requests.rb`
- `db/migrate/*_create_package_items.rb`
- `db/migrate/*_create_package_type_presets.rb`

---

## Summary

This SOP provides a complete, production-ready pattern for implementing multi-mode interfaces with nested forms in Rails. The key principles are:

1. **Database-first design** (migrations, models, associations)
2. **Stimulus for interactivity** (tab switching, dynamic forms)
3. **Partial-based UI** (reusable, themeable components)
4. **Proper security** (strong parameters, validation by mode)
5. **Theme consistency** (role-based color schemes)

Follow this pattern for any similar feature requiring mode switching or nested forms.

---

**Questions or Issues?** Open a GitHub issue or ask in the team Slack channel.
