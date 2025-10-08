# Carrier Matching Algorithm

**Last Updated:** 2025-10-08
**Related Docs:** [Project Architecture](./project_architecture.md), [Database Schema](./database_schema.md), [.agent README](../README.md)

---

## Overview

The **Carrier Matching Algorithm** is the core business logic of the platform. It intelligently matches transport requests with suitable carriers based on multiple criteria including geographic coverage, service radius, vehicle capabilities, and equipment availability.

### Purpose

Automatically identify carriers who can fulfill a transport request by filtering through:
- Vehicle type capabilities
- Geographic service coverage
- Physical proximity (service radius)
- Cargo capacity (for LKW)
- Special equipment requirements

### Location

**Service Object:** `lib/matching/algorithm.rb`
**Distance Calculator:** `lib/matching/distance_calculator.rb`
**Background Job:** `app/jobs/match_carriers_job.rb`
**Email Job:** `app/jobs/send_carrier_invitations_job.rb`

### Design Philosophy

- **Service object pattern** - Business logic separated from controllers/models
- **Sequential filtering** - Multiple stages progressively narrow carrier pool
- **Conservative matching** - Only match carriers who clearly qualify
- **Traceable results** - Every match creates a CarrierRequest record with metadata

---

## High-Level Flow

```
Transport Request Created
         ↓
  Admin clicks "Run Matching"
  (or auto-triggered for customers)
         ↓
  MatchCarriersJob.perform_later
         ↓
  Matching::Algorithm.run
         ↓
  5 Sequential Filters Applied
         ↓
  CarrierRequest Records Created
         ↓
  SendCarrierInvitationsJob.perform_later
         ↓
  Emails Sent to Matched Carriers
```

---

## Algorithm Implementation

### Entry Point: `Matching::Algorithm`

Located in `lib/matching/algorithm.rb:10`

```ruby
def run
  # Start with all active carriers
  carriers = Carrier.active

  # Apply filters sequentially
  carriers = filter_by_vehicle_type(carriers)
  carriers = filter_by_coverage(carriers)
  carriers = filter_by_radius(carriers)
  carriers = filter_by_capacity(carriers)
  carriers = filter_by_equipment(carriers)

  # Create CarrierRequest records for matches
  create_matches(carriers)

  @matched_carriers.count
end
```

**Characteristics:**
- **Immutable filtering** - Each filter returns a new collection
- **Short-circuit safe** - Returns early if no matches remain
- **Metadata preservation** - Final matches store calculated distances
- **Idempotent** - Can be safely re-run (creates new CarrierRequest records)

---

## Filtering Pipeline

The algorithm applies **5 sequential filters** to narrow the carrier pool. Order matters: cheaper checks run first.

### Filter 1: Vehicle Type (`filter_by_vehicle_type`)

**Purpose:** Match carrier's fleet capabilities with request requirements

**Location:** `lib/matching/algorithm.rb:29-40`

**Logic:**
```ruby
case transport_request.vehicle_type
when "transporter"
  carriers.where(has_transporter: true)
when "lkw"
  carriers.where(has_lkw: true)
when "either", nil
  carriers  # No filtering
end
```

**Database Query:**
```sql
SELECT * FROM carriers WHERE has_transporter = 1 AND blacklisted = 0;
-- or
SELECT * FROM carriers WHERE has_lkw = 1 AND blacklisted = 0;
```

**Edge Cases:**
- If `vehicle_type` is `"either"` or `nil`, all carriers pass
- If carrier has *both* transporter and LKW, they match both types
- Blacklisted carriers already excluded by `Carrier.active` scope

---

### Filter 2: Geographic Coverage (`filter_by_coverage`)

**Purpose:** Ensure carrier operates in both pickup and delivery countries

**Location:** `lib/matching/algorithm.rb:42-53`

**Logic:**
```ruby
carriers.select do |carrier|
  pickup_countries = carrier.pickup_countries || []
  delivery_countries = carrier.delivery_countries || []

  pickup_countries.include?(transport_request.start_country) &&
  delivery_countries.include?(transport_request.destination_country)
end
```

**Data Structure:**
- `Carrier.pickup_countries` → `["DE", "AT", "CH"]` (serialized JSON array)
- `Carrier.delivery_countries` → `["DE", "AT", "CH", "PL"]`
- `TransportRequest.start_country` → `"DE"` (extracted via Geocoder)
- `TransportRequest.destination_country` → `"PL"`

**Example:**

| Carrier | Pickup Countries | Delivery Countries | Request Route | Match? |
|---------|------------------|-------------------|---------------|--------|
| Carrier A | `["DE", "AT"]` | `["DE", "PL"]` | DE → PL | ✅ Yes |
| Carrier B | `["DE", "AT"]` | `["DE", "AT"]` | DE → PL | ❌ No (can't deliver to PL) |
| Carrier C | `["AT", "CH"]` | `["DE", "PL"]` | DE → PL | ❌ No (doesn't pickup from DE) |

**Edge Cases:**
- If `start_country` or `destination_country` is `nil`, skip this filter entirely (all carriers pass)
- Empty arrays (`[]`) mean carrier covers *no countries* → won't match
- Case-sensitive matching (country codes stored uppercase: `"DE"`, `"AT"`)

---

### Filter 3: Service Radius (`filter_by_radius`)

**Purpose:** Ensure carrier is physically close enough to pickup location to service the request

**Location:** `lib/matching/algorithm.rb:55-75`

**Logic:**
```ruby
carriers.select do |carrier|
  # Skip radius check if carrier ignores radius
  next true if carrier.ignore_radius

  # Skip if carrier has no location or radius set
  next false unless carrier.latitude && carrier.longitude && carrier.pickup_radius_km

  # Calculate distance from carrier to pickup point
  distance = DistanceCalculator.haversine(
    carrier.latitude,
    carrier.longitude,
    transport_request.start_latitude,
    transport_request.start_longitude
  )

  distance && distance <= carrier.pickup_radius_km
end
```

**Distance Calculation:**
Uses the **Haversine formula** for great-circle distance on a sphere (Earth's surface).

**Why Not Geocoder Gem?**
- **Precision:** Need exact formula for consistent radius filtering in SQLite queries
- **Control:** Custom implementation allows future optimization (e.g., bounding box pre-filter)
- **No external API calls:** Pure math calculation, works offline

**Example:**

| Carrier | Location | Radius (km) | Pickup Location | Distance | Match? |
|---------|----------|-------------|-----------------|----------|--------|
| Carrier A | Berlin | 100 | Hamburg | 255 km | ❌ No |
| Carrier B | Berlin | 300 | Hamburg | 255 km | ✅ Yes |
| Carrier C | Munich | 50 | Berlin | 504 km | ❌ No |
| Carrier D | Berlin | N/A | Hamburg | 255 km | ❌ No (no radius set) |
| Carrier E | Berlin | N/A (`ignore_radius: true`) | Hamburg | 255 km | ✅ Yes (ignores radius) |

**Edge Cases:**
- **`ignore_radius: true`** → Always passes (carrier willing to travel anywhere)
- **Missing lat/lon** → Fails (cannot calculate distance)
- **Missing `pickup_radius_km`** → Fails (no service area defined)
- **`pickup_radius_km: 0`** → Fails (zero radius means no service)
- If `start_latitude` or `start_longitude` is `nil`, skip filter entirely (all carriers pass)

**Performance Note:**
- This is the **most expensive filter** (Haversine calculation per carrier)
- Runs after cheaper filters (vehicle type, coverage) to minimize iterations
- SQLite query optimization: Computed in Ruby memory, not SQL (no spatial indexes)

---

### Filter 4: Cargo Capacity (`filter_by_capacity`)

**Purpose:** For LKW requests, ensure carrier's vehicle can physically accommodate the cargo dimensions

**Location:** `lib/matching/algorithm.rb:77-92`

**Logic:**
```ruby
# Only filter if LKW is required and dimensions are specified
return carriers unless transport_request.vehicle_type == "lkw"
return carriers unless transport_request.cargo_length_cm ||
                      transport_request.cargo_width_cm ||
                      transport_request.cargo_height_cm

carriers.select do |carrier|
  next false unless carrier.has_lkw

  # Check if carrier's LKW can accommodate cargo
  length_ok = !transport_request.cargo_length_cm ||
              !carrier.lkw_length_cm ||
              carrier.lkw_length_cm >= transport_request.cargo_length_cm

  width_ok = !transport_request.cargo_width_cm ||
             !carrier.lkw_width_cm ||
             carrier.lkw_width_cm >= transport_request.cargo_width_cm

  height_ok = !transport_request.cargo_height_cm ||
              !carrier.lkw_height_cm ||
              carrier.lkw_height_cm >= transport_request.cargo_height_cm

  length_ok && width_ok && height_ok
end
```

**When This Filter Applies:**
- **Only** when `transport_request.vehicle_type == "lkw"`
- **Only** when at least one cargo dimension is specified
- For transporter requests, this filter is **skipped** (transporters have flexible capacity)

**Comparison Logic (Per Dimension):**
```ruby
# Request: 500 cm long cargo
# Carrier: 600 cm long LKW
carrier.lkw_length_cm >= transport_request.cargo_length_cm  # ✅ 600 >= 500

# Permissive fallback:
!transport_request.cargo_length_cm  # Dimension not specified → pass
!carrier.lkw_length_cm              # Carrier hasn't listed capacity → assume adequate
```

**Example:**

| Request Cargo (L×W×H cm) | Carrier LKW (L×W×H cm) | Match? | Reason |
|-------------------------|----------------------|--------|--------|
| 500×200×180 | 600×240×200 | ✅ Yes | All dimensions fit |
| 700×200×180 | 600×240×200 | ❌ No | Length exceeds capacity |
| 500×200×180 | 600×180×200 | ❌ No | Width exceeds capacity |
| 500×200×180 | `nil×nil×nil` | ✅ Yes | Carrier capacity unknown (permissive) |
| `nil×nil×nil` | 600×240×200 | ✅ Yes | Cargo dimensions not specified |

**Edge Cases:**
- **Partial dimensions:** If request specifies only length (500 cm), only length is checked
- **Missing carrier dimensions:** Assumed adequate (permissive matching)
- **Zero dimensions:** Treated as `nil` (would fail validation earlier in models)
- **Transporter requests:** This filter is **always skipped** (transporters use loading meters, not dimensions)

**Design Decision: Why Permissive?**
- **Data quality:** Not all carriers have entered vehicle dimensions yet
- **Business logic:** Better to over-match and let carriers decline offers than under-match
- **Customer safety:** Carriers will refuse offers they can't fulfill, but we don't want to miss potential matches

---

### Filter 5: Equipment Requirements (`filter_by_equipment`)

**Purpose:** Ensure carrier has necessary special equipment requested by customer

**Location:** `lib/matching/algorithm.rb:94-107`

**Logic:**
```ruby
carriers.select do |carrier|
  # Check liftgate requirement
  liftgate_ok = !transport_request.requires_liftgate || carrier.has_liftgate

  # Check pallet jack requirement
  pallet_jack_ok = !transport_request.requires_pallet_jack || carrier.has_pallet_jack

  # Check GPS tracking requirement
  gps_ok = !transport_request.requires_gps_tracking || carrier.has_gps_tracking

  liftgate_ok && pallet_jack_ok && gps_ok
end
```

**Boolean Logic:**
```ruby
# If requirement is NOT needed → always OK
!transport_request.requires_liftgate  # false → true (passes)

# If requirement IS needed → carrier must have it
transport_request.requires_liftgate && carrier.has_liftgate  # both true → passes
```

**Equipment Types:**

| Equipment | Purpose | Request Field | Carrier Field |
|-----------|---------|--------------|--------------|
| **Liftgate** | Loading/unloading without dock | `requires_liftgate` | `has_liftgate` |
| **Pallet Jack** | Moving palletized cargo | `requires_pallet_jack` | `has_pallet_jack` |
| **GPS Tracking** | Real-time shipment tracking | `requires_gps_tracking` | `has_gps_tracking` |

**Example:**

| Request Requirements | Carrier Equipment | Match? |
|---------------------|------------------|--------|
| Liftgate ✅, Pallet Jack ✅, GPS ❌ | Liftgate ✅, Pallet Jack ✅, GPS ❌ | ✅ Yes |
| Liftgate ✅, Pallet Jack ❌, GPS ❌ | Liftgate ✅, Pallet Jack ❌, GPS ✅ | ✅ Yes (extra GPS is fine) |
| Liftgate ✅, Pallet Jack ❌, GPS ❌ | Liftgate ❌, Pallet Jack ✅, GPS ✅ | ❌ No (missing liftgate) |
| No requirements | No equipment | ✅ Yes |
| No requirements | All equipment | ✅ Yes |

**Edge Cases:**
- **Additional equipment fields** (future):
  - `requires_side_loading` → Add to filter with same logic
  - `requires_tarp` → Add to filter
  - Pattern is extensible for new equipment types
- **False positives:** If carrier has equipment but it's broken/unavailable, they should decline the offer manually
- **Missing data:** If carrier hasn't specified equipment (`nil`), treated as `false` (doesn't have it)

**Design Decision: Why Strict for Equipment?**
- Equipment requirements are often **hard constraints** (customer site may lack loading dock → requires liftgate)
- Better to under-match and have customer contact carriers manually than over-match and waste carrier time
- Contrast with capacity filter (permissive) vs equipment filter (strict)

---

## Match Creation (`create_matches`)

**Purpose:** Convert filtered carrier list into persistent `CarrierRequest` records with calculated metadata

**Location:** `lib/matching/algorithm.rb:109-148`

### Data Persisted Per Match

```ruby
CarrierRequest.create!(
  transport_request: transport_request,
  carrier: carrier,
  status: "new",
  distance_to_pickup_km: distance_to_pickup&.round(2),
  distance_to_delivery_km: distance_to_delivery&.round(2),
  in_radius: in_radius
)
```

**Fields:**

| Field | Type | Purpose | Example |
|-------|------|---------|---------|
| `transport_request` | Association | Links to the transport request | `TransportRequest #42` |
| `carrier` | Association | Links to the matched carrier | `Carrier #7` |
| `status` | String | Lifecycle status | `"new"` → `"sent"` → `"offered"` → `"won"` |
| `distance_to_pickup_km` | Decimal | Distance from carrier to pickup | `125.47` km |
| `distance_to_delivery_km` | Decimal | Distance from carrier to delivery | `387.92` km |
| `in_radius` | Boolean | Whether pickup is within service radius | `true` |

### Distance Calculations

**Distance to Pickup:**
```ruby
distance_to_pickup = DistanceCalculator.haversine(
  carrier.latitude,
  carrier.longitude,
  transport_request.start_latitude,
  transport_request.start_longitude
)
```

**Distance to Delivery:**
```ruby
distance_to_delivery = DistanceCalculator.haversine(
  carrier.latitude,
  carrier.longitude,
  transport_request.destination_latitude,
  transport_request.destination_longitude
)
```

**In Radius Check:**
```ruby
in_radius = if carrier.pickup_radius_km && distance_to_pickup
  distance_to_pickup <= carrier.pickup_radius_km
else
  carrier.ignore_radius  # Carriers who ignore radius marked as in_radius: true
end
```

### Why Store Distances?

1. **Avoid recalculation** - Expensive Haversine formula computed once
2. **Offer context** - Carriers see how far they need to travel in invitation email
3. **Sorting** - Admin can view offers sorted by proximity
4. **Analytics** - Track average distances, optimize carrier coverage areas
5. **Transparency** - `in_radius` flag shows if match was due to proximity or `ignore_radius`

---

## Distance Calculator (`Matching::DistanceCalculator`)

**Location:** `lib/matching/distance_calculator.rb`

### Haversine Formula

```ruby
def self.haversine(lat1, lon1, lat2, lon2)
  return nil if [lat1, lon1, lat2, lon2].any?(&:nil?)

  # Convert to radians
  lat1_rad = to_radians(lat1)
  lat2_rad = to_radians(lat2)
  delta_lat = to_radians(lat2 - lat1)
  delta_lon = to_radians(lon2 - lon1)

  # Haversine formula
  a = Math.sin(delta_lat / 2)**2 +
      Math.cos(lat1_rad) * Math.cos(lat2_rad) *
      Math.sin(delta_lon / 2)**2

  c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

  EARTH_RADIUS_KM * c
end
```

### Mathematical Background

**Haversine Formula:**
```
a = sin²(Δlat/2) + cos(lat1) × cos(lat2) × sin²(Δlon/2)
c = 2 × atan2(√a, √(1−a))
distance = R × c
```

Where:
- `R` = Earth's radius = 6371 km
- `Δlat` = lat2 - lat1 (in radians)
- `Δlon` = lon2 - lon1 (in radians)

**Accuracy:**
- ✅ Accurate for distances up to ~500 km (typical transport routes)
- ✅ Accounts for Earth's curvature (great-circle distance)
- ⚠️ Assumes spherical Earth (not ellipsoid) - negligible error for this use case
- ⚠️ Ignores road networks (straight-line distance, not driving distance)

**Alternative: Vincenty Formula**
- More accurate (ellipsoidal model), but computationally expensive
- Haversine sufficient for carrier matching (we're checking rough proximity, not billing)

### Why Not Use Geocoder Gem's Distance?

**Geocoder Option:**
```ruby
Geocoder::Calculations.distance_between([lat1, lon1], [lat2, lon2])
```

**Reasons for Custom Implementation:**
1. **Explicit formula** - Full control over calculation method
2. **No external dependency** - Doesn't rely on Geocoder's internal implementation
3. **Performance** - Can be optimized independently (e.g., batch calculations)
4. **Consistency** - Same formula used everywhere in codebase
5. **Testing** - Easier to test in isolation

---

## Background Job Flow

### Job 1: `MatchCarriersJob`

**Purpose:** Asynchronously run the matching algorithm and trigger email job

**Location:** `app/jobs/match_carriers_job.rb:4-20`

**Workflow:**
```ruby
def perform(transport_request_id)
  transport_request = TransportRequest.find(transport_request_id)

  # Run the matching algorithm
  matcher = Matching::Algorithm.new(transport_request)
  match_count = matcher.run

  Rails.logger.info "Matched #{match_count} carriers for TransportRequest ##{transport_request.id}"

  # Chain the invitation job if matches were found
  if match_count > 0
    SendCarrierInvitationsJob.perform_later(transport_request_id)
  else
    # No matches found, update status
    transport_request.update(status: "new")
  end
end
```

**Key Points:**
- **Async execution** - Uses Solid Queue (Rails 8 default)
- **Chained jobs** - If matches found → trigger `SendCarrierInvitationsJob`
- **Zero matches** - Resets status to `"new"` (admin can adjust criteria and re-run)
- **Logging** - Records match count for debugging/analytics

---

### Job 2: `SendCarrierInvitationsJob`

**Purpose:** Send invitation emails to all matched carriers

**Location:** `app/jobs/send_carrier_invitations_job.rb:4-22`

**Workflow:**
```ruby
def perform(transport_request_id)
  transport_request = TransportRequest.find(transport_request_id)

  # Get all pending carrier requests for this transport request
  carrier_requests = transport_request.carrier_requests.where(status: "new")

  carrier_requests.each do |carrier_request|
    # Send invitation email
    CarrierMailer.invitation(carrier_request.id).deliver_later

    # Update carrier request status
    carrier_request.update(
      status: "sent",
      email_sent_at: Time.current
    )
  end

  Rails.logger.info "Sent #{carrier_requests.count} invitations for TransportRequest ##{transport_request.id}"
end
```

**Key Points:**
- **Filters by status** - Only emails `status: "new"` carrier requests (avoids duplicate emails)
- **Updates metadata** - Sets `email_sent_at` timestamp for tracking
- **Queued emails** - Uses `deliver_later` for async email delivery
- **Status transition** - `"new"` → `"sent"`

**Email Contents:**
- Transport request details (route, dates, cargo)
- Calculated distances (pickup and delivery)
- Unique token link to offer submission form
- Language-specific template (German/English based on `carrier.language`)

---

## Complete Data Flow

### 1. Trigger (Admin Interface)

**Controller Action:** `Admin::TransportRequestsController#run_matching`

**Location:** `app/controllers/admin/transport_requests_controller.rb:60-68`

```ruby
def run_matching
  if @transport_request.status == "new"
    MatchCarriersJob.perform_later(@transport_request.id)
    @transport_request.update(status: "matching")
    redirect_to admin_transport_request_path(@transport_request),
                notice: "Matching process started. Invitations will be sent shortly."
  else
    redirect_to admin_transport_request_path(@transport_request),
                alert: "Cannot run matching for this request."
  end
end
```

**Preconditions:**
- Transport request must have `status: "new"`
- Transport request must have valid geocoded addresses (`start_latitude`, `start_longitude`, `destination_latitude`, `destination_longitude`)

**Status Transition:** `"new"` → `"matching"`

---

### 2. Matching Execution (Background Job)

**Job:** `MatchCarriersJob.perform_later(transport_request_id)`

**Steps:**
1. Load transport request from database
2. Initialize `Matching::Algorithm` with transport request
3. Run 5 sequential filters (vehicle type, coverage, radius, capacity, equipment)
4. Create `CarrierRequest` records for all matches with calculated distances
5. If matches found → trigger `SendCarrierInvitationsJob`
6. If no matches → reset status to `"new"`

**Database Changes:**
- `CarrierRequest` records created (1 per matched carrier)
- `TransportRequest.status` remains `"matching"` (updated after emails sent)

---

### 3. Email Invitations (Background Job)

**Job:** `SendCarrierInvitationsJob.perform_later(transport_request_id)`

**Steps:**
1. Load transport request and all `CarrierRequest` records with `status: "new"`
2. For each carrier request:
   - Send `CarrierMailer.invitation` email (queued)
   - Update `carrier_request.status` to `"sent"`
   - Set `carrier_request.email_sent_at` to current timestamp
3. Log total invitation count

**Email Contents (German):**
```
Betreff: Neue Transportanfrage - [Start Ort] → [Ziel Ort]

Guten Tag,

Wir haben eine neue Transportanfrage, die zu Ihrem Serviceangebot passt.

Transportdetails:
- Route: [Start] → [Ziel]
- Abholung: [Datum]
- Lieferung: [Datum]
- Fahrzeugtyp: [Transporter/LKW]
- Entfernung: [X km]

Entfernung von Ihrem Standort:
- Zur Abholung: [X km]
- Zur Lieferung: [X km]

Um ein Angebot abzugeben, klicken Sie bitte hier:
[Unique Token Link]

Mit freundlichen Grüßen,
Das Matchmaking-Team
```

---

### 4. Carrier Offer Submission (Public Form)

**Controller:** `OffersController#show` (public, no authentication)

**URL:** `/offers/{token}/submit`

**Steps:**
1. Carrier clicks unique link from email
2. Token validated, `CarrierRequest` loaded
3. Form displays transport request details + fields for offer
4. Carrier submits: price, delivery date, transport type, notes
5. `CarrierRequest` updated:
   - `status: "offered"`
   - `offered_price`, `offered_delivery_date`, `offered_transport_type`, `offer_notes`
6. Customer/admin notified (future: email notification)

**Status Transition:** `"sent"` → `"offered"`

---

### 5. Customer/Admin Review & Acceptance

**Customer Portal:** `Customer::CarrierRequestsController#accept`
**Admin Portal:** `Admin::CarrierRequestsController#accept`

**Steps:**
1. Customer/admin views all offers for a transport request
2. Selects best offer and clicks "Accept"
3. Accepted offer:
   - `carrier_request.status` → `"won"`
   - `transport_request.matched_carrier_id` → `carrier.id`
   - `transport_request.status` → `"matched"`
4. Other offers:
   - `carrier_request.status` → `"rejected"`
5. Emails sent:
   - Winning carrier → "Offer Accepted"
   - Rejected carriers → "Offer Rejected"

**Status Transition:** `"offered"` → `"won"` or `"rejected"`

---

## Status Lifecycle (CarrierRequest)

```
new → sent → offered → won
                ↓
              rejected
```

| Status | Meaning | Next State |
|--------|---------|------------|
| `new` | Match created, email not yet sent | `sent` |
| `sent` | Invitation email sent to carrier | `offered`, `rejected` (no response) |
| `offered` | Carrier submitted an offer | `won`, `rejected` |
| `won` | Carrier's offer accepted by customer | *(final)* |
| `rejected` | Carrier's offer rejected or ignored | *(final)* |

---

## Edge Cases & Error Handling

### 1. No Carriers Match

**Scenario:** All carriers filtered out (no matches)

**Behavior:**
- `matcher.run` returns `0`
- `MatchCarriersJob` resets `transport_request.status` to `"new"`
- No emails sent
- Admin can:
  - Adjust transport request criteria (e.g., increase pickup/delivery countries)
  - Add more carriers to database
  - Re-run matching

**Solution:** Inform admin of zero matches with specific filter breakdowns (future enhancement)

---

### 2. Missing Geocoding Data

**Scenario:** Transport request has `start_latitude: nil` or `destination_latitude: nil`

**Behavior:**
- **Coverage filter** - Skipped (all carriers pass)
- **Radius filter** - Skipped (all carriers pass)
- **Distance calculations** - Return `nil`, stored as `NULL` in database
- **Match succeeds** but without distance data

**Problem:** Cannot accurately filter by radius or show distances in emails

**Solution:** Ensure geocoding happens before matching:
```ruby
# In controller, before saving transport request
geocode_addresses(@transport_request)
@transport_request.save!
```

---

### 3. Carrier Missing Location

**Scenario:** Carrier has `latitude: nil` or `longitude: nil`

**Behavior:**
- **Radius filter** - Carrier fails (cannot calculate distance)
- **Distance calculations** - Return `nil`
- **Match fails** unless `carrier.ignore_radius: true`

**Solution:** Encourage carriers to enter address (geocoded automatically via `after_validation :geocode`)

---

### 4. Duplicate Matching

**Scenario:** Admin clicks "Run Matching" multiple times

**Behavior:**
- **Creates duplicate `CarrierRequest` records** (no uniqueness constraint)
- **Sends duplicate emails** to same carriers

**Problem:** Carrier receives multiple invitations for same transport request

**Solution (Future):**
- Add unique index: `[:transport_request_id, :carrier_id]`
- Add validation: `validates :carrier_id, uniqueness: { scope: :transport_request_id }`
- Or: Check if `CarrierRequest` already exists before creating

---

### 5. Carrier Capacity Unknown

**Scenario:** Carrier has `lkw_length_cm: nil` (hasn't entered vehicle dimensions)

**Behavior:**
- **Capacity filter** - Carrier passes (permissive matching)
- Carrier receives invitation even if vehicle may be too small

**Philosophy:** Over-match and let carriers decline (better than under-match)

---

### 6. Extremely Large Service Radius

**Scenario:** Carrier sets `pickup_radius_km: 10000` (covers entire continent)

**Behavior:**
- **Radius filter** - Carrier passes (distance always ≤ 10,000 km in Europe)
- May receive offers for routes they don't actually service

**Solution:** Add validation: `validates :pickup_radius_km, numericality: { less_than_or_equal_to: 1000 }`

---

## Performance Characteristics

### Complexity Analysis

**Time Complexity:** `O(n)` where `n` = number of active carriers

**Filter Breakdown:**
1. **Vehicle Type** - `O(n)` - Database query with index on `has_transporter`, `has_lkw`
2. **Coverage** - `O(n)` - Ruby iteration (serialized arrays in SQLite)
3. **Radius** - `O(n)` - Ruby iteration with Haversine calculation per carrier
4. **Capacity** - `O(n)` - Ruby iteration with dimension comparisons
5. **Equipment** - `O(n)` - Ruby iteration with boolean checks
6. **Match Creation** - `O(m)` - Database inserts where `m` = matched carriers (typically `m << n`)

**Bottleneck:** Radius filter (Haversine calculations in Ruby)

---

### Optimization Opportunities

#### 1. Bounding Box Pre-Filter

**Idea:** Narrow carrier pool with database query before Haversine

```ruby
# Approximate bounding box (1 degree latitude ≈ 111 km)
lat_delta = transport_request.pickup_radius_km / 111.0
lon_delta = transport_request.pickup_radius_km / (111.0 * Math.cos(transport_request.start_latitude * Math::PI / 180))

carriers = carriers.where(
  "latitude BETWEEN ? AND ? AND longitude BETWEEN ? AND ?",
  transport_request.start_latitude - lat_delta,
  transport_request.start_latitude + lat_delta,
  transport_request.start_longitude - lon_delta,
  transport_request.start_longitude + lon_delta
)
```

**Benefit:** Reduces Haversine calculations by ~80-90% for most queries

---

#### 2. Database Indexes

**Missing Indexes:**
```ruby
# db/migrate/YYYYMMDDHHMMSS_add_matching_indexes.rb
add_index :carriers, :has_transporter
add_index :carriers, :has_lkw
add_index :carriers, :blacklisted
add_index :carriers, [:latitude, :longitude]
add_index :carrier_requests, [:transport_request_id, :status]
```

**Impact:** Faster vehicle type filtering and carrier request queries

---

#### 3. Eager Loading

**Current:** N+1 queries when accessing `CarrierRequest.carrier` in email job

**Optimization:**
```ruby
carrier_requests = transport_request.carrier_requests.includes(:carrier).where(status: "new")
```

---

#### 4. Background Job Batching

**Current:** One email job per carrier (1 carrier = 1 job)

**Optimization:** Batch emails (10 carriers per job)
```ruby
carrier_requests.each_slice(10) do |batch|
  CarrierMailer.batch_invitations(batch.map(&:id)).deliver_later
end
```

---

## Testing Approach

### Manual Testing Checklist

**Test Case 1: Basic Matching**
- [ ] Create transport request: DE → PL, transporter
- [ ] Create carrier: Covers DE/PL, has transporter, in radius
- [ ] Run matching → 1 match expected

**Test Case 2: Vehicle Type Filter**
- [ ] Transport request requires LKW
- [ ] Carrier has only transporter
- [ ] Run matching → 0 matches expected

**Test Case 3: Coverage Filter**
- [ ] Transport request: DE → FR
- [ ] Carrier covers DE/PL (not FR)
- [ ] Run matching → 0 matches expected

**Test Case 4: Radius Filter**
- [ ] Transport request pickup: Berlin
- [ ] Carrier location: Munich (504 km away)
- [ ] Carrier radius: 300 km
- [ ] Run matching → 0 matches expected

**Test Case 5: Equipment Filter**
- [ ] Transport request requires liftgate
- [ ] Carrier has no liftgate
- [ ] Run matching → 0 matches expected

**Test Case 6: Multiple Matches**
- [ ] Create 5 qualifying carriers
- [ ] Run matching → 5 matches expected
- [ ] All receive invitation emails

**Test Case 7: Zero Matches**
- [ ] Transport request with very specific criteria
- [ ] No carriers qualify
- [ ] Run matching → 0 matches, status resets to "new"

---

### Automated Testing (Future)

**Unit Tests: `Matching::Algorithm`**
```ruby
RSpec.describe Matching::Algorithm do
  describe "#filter_by_vehicle_type" do
    it "matches carriers with transporter when transporter required"
    it "matches carriers with LKW when LKW required"
    it "matches all carriers when vehicle type is 'either'"
  end

  describe "#filter_by_coverage" do
    it "matches carriers covering both pickup and delivery countries"
    it "excludes carriers not covering pickup country"
    it "excludes carriers not covering delivery country"
  end

  describe "#filter_by_radius" do
    it "matches carriers within service radius"
    it "excludes carriers outside service radius"
    it "matches carriers with ignore_radius flag regardless of distance"
  end

  # ... more specs
end
```

**Integration Tests: `MatchCarriersJob`**
```ruby
RSpec.describe MatchCarriersJob do
  it "creates CarrierRequest records for matching carriers" do
    # Setup transport request and carriers
    expect {
      MatchCarriersJob.perform_now(transport_request.id)
    }.to change(CarrierRequest, :count).by(expected_matches)
  end

  it "chains SendCarrierInvitationsJob when matches found" do
    expect(SendCarrierInvitationsJob).to receive(:perform_later).with(transport_request.id)
    MatchCarriersJob.perform_now(transport_request.id)
  end
end
```

---

## Future Enhancements

### 1. Smart Ranking (Not Just Filtering)

**Current:** All matched carriers treated equally

**Idea:** Rank carriers by suitability score:
```ruby
score = (
  proximity_weight * (1 - distance_to_pickup / max_distance) +
  rating_weight * (carrier.rating_punctuality / 5.0) +
  price_weight * (1 - carrier.avg_price / max_price)
)
```

**Benefit:** Show customer "best match" first

---

### 2. Historical Performance Weighting

**Idea:** Prefer carriers with:
- High acceptance rate (accepts offers vs declines)
- High on-time delivery rate
- High customer ratings

**Implementation:**
```ruby
carriers = carriers.sort_by do |carrier|
  carrier.acceptance_rate * 0.4 +
  carrier.on_time_rate * 0.4 +
  carrier.avg_rating * 0.2
end.reverse
```

---

### 3. Real-Time Capacity Management

**Idea:** Track carrier availability (number of active jobs)

**Schema:**
```ruby
add_column :carriers, :max_concurrent_jobs, :integer, default: 5
add_column :carriers, :current_active_jobs, :integer, default: 0
```

**Filter:**
```ruby
carriers.select { |carrier| carrier.current_active_jobs < carrier.max_concurrent_jobs }
```

---

### 4. Batch Matching

**Current:** Match one transport request at a time

**Idea:** Match multiple transport requests simultaneously, optimize carrier assignments

**Use Case:** Customer uploads 10 transport requests → find optimal carrier assignments

**Complexity:** Constraint satisfaction problem (CSP), requires advanced algorithm

---

### 5. Match Explanations

**Idea:** Show admin *why* a carrier matched or didn't match

**Example Output:**
```
Carrier A: ✅ Matched
- Vehicle Type: ✅ Has transporter
- Coverage: ✅ Covers DE/PL
- Radius: ✅ Within 100 km (actual: 87 km)
- Equipment: ✅ Has liftgate

Carrier B: ❌ Not Matched
- Vehicle Type: ✅ Has transporter
- Coverage: ✅ Covers DE/PL
- Radius: ❌ Outside 50 km (actual: 155 km)
```

**Benefit:** Helps admin understand matching logic, adjust criteria

---

## Related Files & Code References

**Core Algorithm:**
- `lib/matching/algorithm.rb:10-148` - Main algorithm
- `lib/matching/distance_calculator.rb:7-32` - Haversine formula

**Background Jobs:**
- `app/jobs/match_carriers_job.rb:4-20` - Matching job
- `app/jobs/send_carrier_invitations_job.rb:4-22` - Email job

**Controllers (Triggers):**
- `app/controllers/admin/transport_requests_controller.rb:60-68` - Admin trigger

**Models:**
- `app/models/carrier.rb:23` - `active` scope (excludes blacklisted)
- `app/models/transport_request.rb` - Geocoding logic
- `app/models/carrier_request.rb` - Match record

**Emails:**
- `app/mailers/carrier_mailer.rb` - Invitation email template
- `app/views/carrier_mailer/invitation.html.erb` - Email view

---

## Maintenance Notes

### When to Review This Algorithm

**Regularly:**
- Monthly: Check match rates (% of transport requests with at least 1 match)
- Quarterly: Analyze carrier response rates (accepts vs declines)

**Triggers for Changes:**
- Match rate drops below 70% (too strict)
- Response rate drops below 30% (too permissive)
- New business requirements (e.g., hazmat certifications, temperature control)

**Version History:**

| Date | Change | Reason |
|------|--------|--------|
| 2025-10-05 | Initial implementation | MVP launch |
| 2025-10-08 | Documented | System documentation initiative |

---

**Last Review:** 2025-10-08
**Next Review Due:** 2025-11-08
