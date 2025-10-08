# SOP: Implementing Quote & Pricing System

**Last Updated:** 2025-10-08
**Author:** Claude Code
**Related Docs:** `../System/database_schema.md`, `../Tasks/quote_system_prd.md`

---

## Overview

This SOP documents the implementation of the automated quote generation and pricing calculator system for transport requests. This feature allows the platform to automatically generate price quotes for customers based on configurable pricing rules.

## Architecture Components

### 1. Database Models

#### Quote Model (`app/models/quote.rb`)
- **Purpose:** Stores generated price quotes for transport requests
- **Key Relationships:**
  - `belongs_to :transport_request` (1:1 relationship)
  - `has_many :quote_line_items` (1:N relationship with inverse)
- **Statuses:** `pending`, `accepted`, `declined`, `expired`
- **Key Fields:**
  - `base_price`: Base transportation cost
  - `surcharge_total`: Sum of all surcharges
  - `total_price`: Final quote price
  - `currency`: Currency code (e.g., EUR)
  - `accepted_at`, `declined_at`: Timestamps for actions

#### QuoteLineItem Model (`app/models/quote_line_item.rb`)
- **Purpose:** Breaks down quote into individual cost components
- **Key Relationships:**
  - `belongs_to :quote` (with inverse to parent)
- **Key Fields:**
  - `description`: Human-readable line item name
  - `calculation`: Formula/explanation of how this was calculated
  - `amount`: Cost for this line item
  - `line_order`: Display order (0 = base cost, 1+ = surcharges)

#### PricingRule Model (`app/models/pricing_rule.rb`)
- **Purpose:** Configurable pricing rules per vehicle type
- **Key Fields:**
  - `vehicle_type`: Vehicle category (transporter, sprinter, lkw_7_5t, etc.)
  - `rate_per_km`: Base rate per kilometer
  - `minimum_price`: Minimum charge regardless of distance
  - `weekend_surcharge_percent`: Extra % for weekend pickups
  - `express_surcharge_percent`: Extra % for <24hr deliveries

### 2. Business Logic Layer

#### Pricing Calculator (`lib/pricing/calculator.rb`)
- **Purpose:** Calculates quotes using pricing rules and transport request data
- **Key Methods:**
  - `calculate()`: Main entry point, returns Quote object or nil
  - `find_pricing_rule()`: Matches vehicle type to pricing rule
  - `calculate_base_price()`: Distance × rate_per_km (with minimum)
  - `calculate_surcharges()`: Applies weekend/express surcharges
  - `create_quote()`: Saves Quote with nested QuoteLineItems

**Calculation Logic:**
```ruby
base_price = max(distance_km × rate_per_km, minimum_price)

if weekend_pickup?
  weekend_surcharge = base_price × (weekend_surcharge_percent / 100)
end

if express_delivery? (< 24 hours)
  express_surcharge = base_price × (express_surcharge_percent / 100)
end

total_price = base_price + weekend_surcharge + express_surcharge
```

### 3. Controller Layer

#### Customer::QuotesController
- **Actions:**
  - `accept`: Customer accepts quote → triggers carrier matching
  - `decline`: Customer declines quote
- **Authorization:** Requires `ensure_customer!`
- **Flow:**
  1. Customer creates transport request
  2. System auto-generates quote via `Pricing::Calculator`
  3. Customer sees quote card on request detail page
  4. Customer accepts → status changes, matching begins
  5. Customer declines → status updated, no matching

#### Admin::PricingRulesController
- **Actions:** Full CRUD for pricing rules
- **Authorization:** Requires `ensure_admin!`
- **Purpose:** Admins can configure pricing per vehicle type

### 4. View Layer

#### Quote Card (`app/views/customer/transport_requests/_quote_card.html.erb`)
- **Location:** Rendered on customer transport request show page
- **Features:**
  - Shows quote breakdown with line items
  - Displays calculation formulas
  - Accept/Decline buttons (if pending)
  - Status badges (pending/accepted/declined)

---

## Implementation Steps

### Step 1: Database Migrations

```bash
rails generate migration CreateQuotes transport_request:references status:string base_price:decimal surcharge_total:decimal total_price:decimal currency:string accepted_at:datetime declined_at:datetime valid_until:datetime

rails generate migration CreateQuoteLineItems quote:references description:string calculation:text amount:decimal line_order:integer

rails generate migration CreatePricingRules vehicle_type:string rate_per_km:decimal minimum_price:decimal weekend_surcharge_percent:decimal express_surcharge_percent:decimal currency:string active:boolean

rails db:migrate
```

### Step 2: Create Models

**CRITICAL: Association Setup**

❌ **Wrong (will cause validation errors):**
```ruby
# quote.rb
has_many :quote_line_items, dependent: :destroy

# quote_line_item.rb
belongs_to :quote
validates :quote_id, presence: true  # ← CONFLICT!
```

✅ **Correct:**
```ruby
# quote.rb
has_many :quote_line_items, dependent: :destroy, inverse_of: :quote

# quote_line_item.rb
belongs_to :quote, inverse_of: :quote_line_items
# No validates :quote_id - belongs_to handles it
validates :description, presence: true
validates :amount, presence: true, numericality: true
```

**Why:** When using `build` to create nested records, Rails validates the parent before saving. Without `inverse_of`, the child's `quote_id` validation fails because the parent Quote hasn't been saved yet. The `inverse_of` tells Rails these are the same object.

### Step 3: Add Instance Methods

**CRITICAL: Status Check Methods**

Views use `quote.accepted?` and `quote.declined?` but scopes like `Quote.accepted` are class methods. You must add instance methods:

```ruby
# app/models/quote.rb
def pending?
  status == 'pending'
end

def accepted?
  status == 'accepted'
end

def declined?
  status == 'declined'
end
```

### Step 4: Create Pricing Calculator

**Location:** `lib/pricing/calculator.rb`

**Key Patterns:**
1. **Validation First:** Check request has required data before calculating
2. **Error Collection:** Store errors in `@errors` array for debugging
3. **Transaction Safety:** Use `Quote.transaction do ... end` when creating quote + line items
4. **Fallback Logic:** Handle edge cases (e.g., `either` → `transporter`)

**Example Usage:**
```ruby
# In controller or job
calculator = Pricing::Calculator.new(@transport_request)
quote = calculator.calculate

if quote
  # Success - quote saved with line items
  redirect_to customer_transport_request_path(@transport_request)
else
  # Errors
  flash[:alert] = calculator.errors.join(', ')
  redirect_back fallback_location: root_path
end
```

### Step 5: Add Routes

```ruby
# config/routes.rb
namespace :customer do
  resources :transport_requests do
    resource :quote, only: [] do
      post :accept
      post :decline
    end
  end
end

namespace :admin do
  resources :pricing_rules
end
```

### Step 6: Create Controllers

**Customer::QuotesController Pattern:**
```ruby
before_action :authenticate_user!
before_action :ensure_customer!
before_action :set_transport_request
before_action :set_quote

def accept
  if @quote.accept!  # Uses transaction
    MatchCarriersJob.perform_later(@transport_request.id)
    redirect_to ..., notice: t('quotes.accepted')
  else
    redirect_to ..., alert: t('quotes.accept_failed')
  end
end

private

def set_quote
  @quote = @transport_request.quote
  redirect_to ..., alert: t('quotes.not_found') unless @quote
end
```

### Step 7: Create Views

**Quote Card Structure:**
```erb
<% if transport_request.quote %>
  <!-- Status badge -->
  <!-- Quote breakdown (line items loop) -->
  <!-- Total price -->
  <!-- Accept/Decline buttons (if pending) -->
<% else %>
  <!-- "No quote available" message -->
<% end %>
```

### Step 8: Add Translations

```yaml
# config/locales/en.yml
quotes:
  title: "Quote"
  status:
    pending: "Pending"
    accepted: "Accepted"
    declined: "Declined"
  line_items:
    base_transport: "Base Transport Cost"
    weekend_surcharge: "Weekend Surcharge"
    express_surcharge: "Express Surcharge"
    total: "Total"
  accepted: "Quote accepted. Carriers are now being searched."
  declined: "Quote declined."
  not_found: "No quote found."
```

---

## Testing Checklist

### Manual Testing

1. **Create Pricing Rule:**
   ```bash
   rails console
   PricingRule.create!(
     vehicle_type: 'transporter',
     rate_per_km: 1.50,
     minimum_price: 50.00,
     weekend_surcharge_percent: 20.0,
     express_surcharge_percent: 30.0,
     currency: 'EUR',
     active: true
   )
   ```

2. **Create Transport Request:**
   - As customer, create transport request
   - Set pickup/delivery dates
   - Verify quote appears on show page

3. **Test Quote Actions:**
   - Accept quote → should redirect and start matching
   - Decline quote → should update status
   - Verify buttons disabled after action

4. **Test Edge Cases:**
   - Weekend pickup → verify surcharge applied
   - Express delivery (<24hrs) → verify surcharge applied
   - Both → verify both surcharges
   - Distance < minimum → verify minimum price used

### Automated Testing (Future)

```ruby
# test/models/quote_test.rb
test "should apply weekend surcharge for Saturday pickup"
test "should apply express surcharge for <24hr delivery"
test "should use minimum price when calculated is lower"

# test/lib/pricing/calculator_test.rb
test "should calculate correct base price"
test "should handle missing pricing rule gracefully"
```

---

## Common Issues & Solutions

### Issue 1: "Quote line items is invalid"

**Cause:** Missing `inverse_of` on associations
**Solution:** Add `inverse_of` to both `has_many` and `belongs_to` (see Step 2)

### Issue 2: "NoMethodError: undefined method `accepted?`"

**Cause:** Only scope defined, not instance method
**Solution:** Add instance methods for all statuses (see Step 3)

### Issue 3: Quote not auto-generating

**Cause:** Forgot to call calculator after request creation
**Solution:** Add to controller:
```ruby
def create
  @transport_request = current_user.transport_requests.build(params)
  if @transport_request.save
    # Auto-generate quote
    Pricing::Calculator.new(@transport_request).calculate
    redirect_to ...
  end
end
```

### Issue 4: Surcharges not calculating

**Cause:** Dates stored as strings or nil
**Solution:** Ensure `pickup_date_from` and `delivery_date_from` are proper datetime objects

### Issue 5: No pricing rule found

**Cause:** Vehicle type mismatch
**Solution:** Add fallback logic in `find_pricing_rule()`:
```ruby
rule = PricingRule.find_for_vehicle_type(vehicle_type)
rule ||= PricingRule.find_for_vehicle_type('transporter') # fallback
```

---

## Extension Points

### Adding New Surcharge Types

1. Add columns to `pricing_rules` table:
   ```bash
   rails generate migration AddHazmatSurchargeToPricingRules hazmat_surcharge_percent:decimal
   ```

2. Update calculator:
   ```ruby
   def calculate_surcharges(base_price)
     surcharges = []

     if hazmat_cargo? && pricing_rule.hazmat_surcharge_percent > 0
       surcharges << {
         description: 'Hazardous Materials Surcharge',
         calculation: "#{pricing_rule.hazmat_surcharge_percent}%",
         amount: base_price * pricing_rule.hazmat_surcharge_percent / 100
       }
     end

     surcharges
   end
   ```

3. Add translation keys

### Dynamic Pricing (Future)

To implement dynamic pricing based on demand:

1. Add `demand_multiplier` field to transport requests
2. Create `Pricing::DemandCalculator` service
3. Multiply base price by demand factor
4. Add line item showing demand adjustment

### Multi-Currency Support

1. Add `exchange_rates` table
2. Update calculator to convert based on customer's preferred currency
3. Store both original and converted amounts

---

## Related Files

**Models:**
- `app/models/quote.rb`
- `app/models/quote_line_item.rb`
- `app/models/pricing_rule.rb`
- `app/models/transport_request.rb` (updated with `has_one :quote`)

**Controllers:**
- `app/controllers/customer/quotes_controller.rb`
- `app/controllers/admin/pricing_rules_controller.rb`

**Business Logic:**
- `lib/pricing/calculator.rb`

**Views:**
- `app/views/customer/transport_requests/_quote_card.html.erb`
- `app/views/admin/pricing_rules/index.html.erb`
- `app/views/admin/pricing_rules/_form.html.erb`

**Migrations:**
- `db/migrate/XXXXXX_create_quotes.rb`
- `db/migrate/XXXXXX_create_quote_line_items.rb`
- `db/migrate/XXXXXX_create_pricing_rules.rb`

**Tests:**
- `test/models/quote_test.rb`
- `test/models/pricing_rule_test.rb`
- `test/lib/pricing/calculator_test.rb`

---

## Deployment Notes

1. **Run migrations:**
   ```bash
   rails db:migrate
   ```

2. **Seed initial pricing rules:**
   ```bash
   rails runner "
   PricingRule.create!([
     { vehicle_type: 'transporter', rate_per_km: 1.50, minimum_price: 50, currency: 'EUR', active: true },
     { vehicle_type: 'sprinter', rate_per_km: 0.80, minimum_price: 40, currency: 'EUR', active: true },
     { vehicle_type: 'lkw_7_5t', rate_per_km: 1.15, minimum_price: 80, currency: 'EUR', active: true }
   ])
   "
   ```

3. **Verify routes:**
   ```bash
   rails routes | grep quote
   ```

4. **Test in production console:**
   ```bash
   rails console -e production
   tr = TransportRequest.last
   Pricing::Calculator.new(tr).calculate
   ```

---

## Best Practices

1. ✅ **Always use inverse_of for nested associations**
2. ✅ **Validate in calculator, not just model** (better error messages)
3. ✅ **Store calculation formulas for transparency**
4. ✅ **Use transactions when creating quotes + line items**
5. ✅ **Collect errors in calculator for debugging**
6. ✅ **Internationalize all user-facing strings**
7. ✅ **Add instance methods for all status checks**
8. ✅ **Default to safe fallbacks (e.g., minimum price)**

---

## Maintenance

**Monthly:**
- Review pricing rules for accuracy
- Check for orphaned quotes (deleted requests)
- Analyze conversion rate (accepted vs declined)

**Quarterly:**
- Update surcharge percentages based on costs
- Review and optimize calculator performance
- Add new vehicle types as needed

**Annually:**
- Audit pricing strategy
- Consider implementing dynamic pricing
- Review currency exchange rates (if multi-currency)
