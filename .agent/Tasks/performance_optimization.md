# Performance Optimization Task

**Created:** 2025-10-08
**Status:** Planned (Future Enhancement)
**Priority:** Medium
**Related Docs:** [Project Architecture](../System/project_architecture.md), [Database Schema](../System/database_schema.md), [Carrier Matching Algorithm](../System/carrier_matching_algorithm.md)

---

## Overview

This document outlines identified performance bottlenecks and optimization opportunities for the Matchmaking Platform. These improvements are **deferred until after MVP validation** following the project philosophy: "Make it work, then make it good, then make it fast."

### Current Performance Status

**✅ Adequate for MVP:**
- Expected load: 100-1000 users, 1000-10,000 transport requests
- Database size: < 1GB (SQLite optimal range)
- Background jobs handle heavy operations async

**⚠️ Known Issues:**
- Missing indexes on foreign keys and status columns
- N+1 queries in list views (carrier requests, transport requests)
- No fragment caching for static content
- No counter caches for associations
- Haversine distance calculations in Ruby (not SQL)

---

## When to Implement

Trigger optimization when:
- **Response times** exceed 500ms for 90th percentile
- **Database queries** exceed 50ms average
- **CPU usage** sustained above 80%
- **Memory usage** sustained above 80%
- **User complaints** about slow page loads
- **Database size** exceeds 500MB

**Current Approach:** Monitor metrics, optimize when needed (not prematurely).

---

## Optimization Roadmap

### Phase 1: Low-Hanging Fruit (Quick Wins)
**Estimated Effort:** 1-2 days
**Impact:** High (20-50% performance improvement)

1. Add missing database indexes
2. Fix identified N+1 queries
3. Add basic query result caching

---

### Phase 2: Caching Strategy
**Estimated Effort:** 2-3 days
**Impact:** Medium (10-30% improvement)

1. Fragment caching for static content
2. Counter caches for associations
3. HTTP caching headers

---

### Phase 3: Algorithm Optimization
**Estimated Effort:** 3-5 days
**Impact:** Medium (Scalability improvement)

1. Bounding box pre-filter for radius matching
2. Batch distance calculations
3. Carrier matching result caching

---

### Phase 4: Frontend & Asset Optimization
**Estimated Effort:** 1-2 days
**Impact:** Low-Medium (Perceived performance)

1. Lazy loading for Google Maps
2. Turbo Frame usage for partial updates
3. Asset compression

---

## Phase 1: Database Optimization

### 1.1 Missing Indexes

**Problem:** Foreign keys and frequently queried columns lack indexes, causing slow queries.

#### Indexes to Add

**Migration: `add_performance_indexes.rb`**
```ruby
class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Carrier Requests
    add_index :carrier_requests, :status
    add_index :carrier_requests, :email_sent_at
    add_index :carrier_requests, [:transport_request_id, :status]
    add_index :carrier_requests, [:carrier_id, :status]
    add_index :carrier_requests, :in_radius

    # Transport Requests
    add_index :transport_requests, :status
    add_index :transport_requests, :matched_carrier_id
    add_index :transport_requests, [:user_id, :status]
    add_index :transport_requests, :created_at
    add_index :transport_requests, :pickup_date_from

    # Carriers
    add_index :carriers, :blacklisted
    add_index :carriers, :has_transporter
    add_index :carriers, :has_lkw
    add_index :carriers, [:latitude, :longitude]

    # Quotes
    add_index :quotes, [:transport_request_id, :status]
    add_index :quotes, :accepted_at
    add_index :quotes, :created_at

    # Quote Line Items
    add_index :quote_line_items, :quote_id

    # Package Items
    add_index :package_items, :transport_request_id

    # Users
    add_index :users, :role
    add_index :users, :locale
  end
end
```

**Expected Impact:**
- List queries: 50-80% faster
- Foreign key joins: 30-50% faster
- Status filtering: 60-90% faster

**Testing:**
```ruby
# Before: 150ms
TransportRequest.where(status: 'matching').to_a

# After: 5-10ms
TransportRequest.where(status: 'matching').to_a
```

---

### 1.2 N+1 Query Fixes

**Problem:** Loading associations in loops causes N+1 queries.

#### Issue 1: Carrier Requests Index (Admin)

**Current Code:**
```ruby
# app/controllers/admin/carrier_requests_controller.rb
def index
  @carrier_requests = CarrierRequest.all.order(created_at: :desc)
end
```

**View:**
```erb
<% @carrier_requests.each do |cr| %>
  <%= cr.carrier.company_name %>  <!-- N+1: 1 query per carrier request -->
  <%= cr.transport_request.start_address %>  <!-- N+1: 1 query per carrier request -->
<% end %>
```

**Problem:** 100 carrier requests = 201 queries (1 initial + 100 carriers + 100 transport requests)

**Solution:**
```ruby
def index
  @carrier_requests = CarrierRequest
    .includes(:carrier, :transport_request)
    .order(created_at: :desc)
end
```

**Result:** 100 carrier requests = 3 queries (1 carrier requests + 1 carriers + 1 transport requests)

---

#### Issue 2: Transport Requests Index (Admin)

**Current Code:**
```ruby
def index
  @transport_requests = TransportRequest.all.order(created_at: :desc)
end
```

**View:**
```erb
<% @transport_requests.each do |tr| %>
  <%= tr.user.email %>  <!-- N+1 -->
  <%= tr.matched_carrier&.company_name %>  <!-- N+1 -->
  <%= tr.carrier_requests.count %>  <!-- N+1 (count query) -->
<% end %>
```

**Solution:**
```ruby
def index
  @transport_requests = TransportRequest
    .includes(:user, :matched_carrier)
    .left_joins(:carrier_requests)
    .select('transport_requests.*, COUNT(carrier_requests.id) as carrier_requests_count')
    .group('transport_requests.id')
    .order(created_at: :desc)
end
```

**View:**
```erb
<%= tr.carrier_requests_count %>  <!-- No additional query -->
```

---

#### Issue 3: Customer Dashboard

**Current Code:**
```ruby
def show
  @recent_requests = current_user.transport_requests.recent.limit(10)
end
```

**View:**
```erb
<% @recent_requests.each do |tr| %>
  <%= tr.carrier_requests.offered.count %>  <!-- N+1 -->
  <%= tr.quote&.total_price %>  <!-- N+1 -->
<% end %>
```

**Solution:**
```ruby
def show
  @recent_requests = current_user.transport_requests
    .includes(:quote)
    .left_joins(:carrier_requests)
    .select('transport_requests.*, COUNT(CASE WHEN carrier_requests.status = "offered" THEN 1 END) as offered_count')
    .group('transport_requests.id')
    .recent
    .limit(10)
end
```

---

### 1.3 Query Result Caching

**Problem:** Expensive queries re-executed on every page load.

#### Static Data Caching

**Package Type Presets:**
```ruby
# app/models/package_type_preset.rb
class PackageTypePreset < ApplicationRecord
  def self.all_cached
    Rails.cache.fetch('package_type_presets', expires_in: 1.day) do
      all.to_a
    end
  end
end

# Usage in controller
@presets = PackageTypePreset.all_cached
```

**Pricing Rules:**
```ruby
class PricingRule < ApplicationRecord
  def self.for_vehicle_type_cached(vehicle_type)
    Rails.cache.fetch("pricing_rules/#{vehicle_type}", expires_in: 1.hour) do
      find_by(vehicle_type: vehicle_type)
    end
  end
end
```

---

## Phase 2: Caching Strategy

### 2.1 Fragment Caching

**Problem:** Rendering complex partials on every request.

#### Carrier Details Partial

**Before:**
```erb
<!-- app/views/admin/carriers/_overview.html.erb -->
<div class="carrier-overview">
  <%= render 'carrier_stats', carrier: @carrier %>
  <%= render 'carrier_location_map', carrier: @carrier %>
  <%= render 'carrier_contact_info', carrier: @carrier %>
</div>
```

**After:**
```erb
<% cache @carrier do %>
  <div class="carrier-overview">
    <%= render 'carrier_stats', carrier: @carrier %>
    <%= render 'carrier_location_map', carrier: @carrier %>
    <%= render 'carrier_contact_info', carrier: @carrier %>
  </div>
<% end %>
```

**Cache Key:** Automatically includes `carrier.id` and `carrier.updated_at`

**Expiration:** Automatic when carrier is updated

---

#### Transport Request Show Page

```erb
<% cache [@transport_request, 'show-page'] do %>
  <%= render 'transport_details', request: @transport_request %>
  <%= render 'route_map', request: @transport_request %>
<% end %>

<!-- Don't cache offers (changes frequently) -->
<%= render 'carrier_offers', carrier_requests: @carrier_requests %>
```

---

### 2.2 Counter Caches

**Problem:** Counting associations with `count` triggers query.

#### Carrier Requests Count

**Migration:**
```ruby
class AddCounterCachesToTransportRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :transport_requests, :carrier_requests_count, :integer, default: 0, null: false

    # Backfill existing counts
    TransportRequest.find_each do |tr|
      TransportRequest.reset_counters(tr.id, :carrier_requests)
    end
  end
end
```

**Model:**
```ruby
class CarrierRequest < ApplicationRecord
  belongs_to :transport_request, counter_cache: true
end
```

**Usage:**
```ruby
# Before: SELECT COUNT(*) FROM carrier_requests WHERE transport_request_id = 1
@transport_request.carrier_requests.count

# After: No query, reads from counter cache
@transport_request.carrier_requests_count
```

---

#### Quote Line Items Count

```ruby
class AddCounterCachesToQuotes < ActiveRecord::Migration[8.0]
  def change
    add_column :quotes, :quote_line_items_count, :integer, default: 0, null: false
  end
end

class QuoteLineItem < ApplicationRecord
  belongs_to :quote, counter_cache: true
end
```

---

### 2.3 HTTP Caching Headers

**Problem:** Static assets and pages re-downloaded on every request.

**Application Controller:**
```ruby
class ApplicationController < ActionController::Base
  # Cache static pages for 5 minutes
  def set_cache_headers
    if current_user
      expires_in 5.minutes, public: false
    else
      expires_in 1.hour, public: true
    end
  end
end
```

**Public Pages:**
```ruby
class OffersController < ApplicationController
  def show
    @carrier_request = CarrierRequest.find_by!(token: params[:token])

    # Cache offer page for 10 minutes
    expires_in 10.minutes, public: true
  end
end
```

---

## Phase 3: Algorithm Optimization

### 3.1 Bounding Box Pre-Filter

**Problem:** Haversine calculation runs for ALL carriers, even those far away.

**Current:**
```ruby
def filter_by_radius(carriers)
  carriers.select do |carrier|
    # Calculates distance for EVERY carrier
    distance = DistanceCalculator.haversine(...)
    distance && distance <= carrier.pickup_radius_km
  end
end
```

**Optimized:**
```ruby
def filter_by_radius(carriers)
  # Step 1: Fast bounding box filter (SQL query)
  carriers = apply_bounding_box_filter(carriers)

  # Step 2: Precise Haversine for remaining carriers
  carriers.select do |carrier|
    next true if carrier.ignore_radius
    next false unless carrier.latitude && carrier.longitude && carrier.pickup_radius_km

    distance = DistanceCalculator.haversine(
      carrier.latitude,
      carrier.longitude,
      transport_request.start_latitude,
      transport_request.start_longitude
    )

    distance && distance <= carrier.pickup_radius_km
  end
end

private

def apply_bounding_box_filter(carriers)
  return carriers unless transport_request.start_latitude && transport_request.start_longitude

  # Approximate: 1 degree latitude ≈ 111 km
  # Longitude varies by latitude (narrower near poles)
  max_radius = 500  # Max reasonable pickup radius

  lat_delta = max_radius / 111.0
  lon_delta = max_radius / (111.0 * Math.cos(transport_request.start_latitude * Math::PI / 180))

  carriers.where(
    "(latitude BETWEEN ? AND ?) AND (longitude BETWEEN ? AND ?)",
    transport_request.start_latitude - lat_delta,
    transport_request.start_latitude + lat_delta,
    transport_request.start_longitude - lon_delta,
    transport_request.start_longitude + lon_delta
  )
end
```

**Expected Impact:**
- Reduces Haversine calculations by 80-90%
- Matching time: 200ms → 30ms (for 100 carriers)

---

### 3.2 Batch Distance Calculations

**Problem:** Distance calculated multiple times for same carrier-location pairs.

**Optimization:**
```ruby
class DistanceCalculator
  # Memoize distances within single request
  def self.haversine_memoized(lat1, lon1, lat2, lon2)
    @distance_cache ||= {}
    cache_key = "#{lat1},#{lon1},#{lat2},#{lon2}"

    @distance_cache[cache_key] ||= haversine(lat1, lon1, lat2, lon2)
  end

  def self.clear_cache
    @distance_cache = {}
  end
end
```

---

### 3.3 Matching Result Caching

**Problem:** Re-running matching algorithm for same criteria wastes resources.

**Idea:** Cache matching results for 15 minutes (carriers may change availability).

```ruby
class Matching::Algorithm
  def run
    cache_key = "matching/#{transport_request.id}/#{transport_request.updated_at.to_i}"

    Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
      run_matching_logic
    end
  end

  private

  def run_matching_logic
    # Existing logic...
  end
end
```

**Consideration:** May miss newly added carriers. Trade-off: freshness vs performance.

---

## Phase 4: Frontend & Asset Optimization

### 4.1 Lazy Loading Google Maps

**Problem:** Google Maps API loads on every page, even when not needed.

**Current:**
```javascript
// Loaded globally in layout
```

**Optimized:**
```javascript
// app/javascript/controllers/map_controller.js
connect() {
  if (!this.hasMapTarget) return;

  if (typeof google !== 'undefined') {
    this.initMap();
  } else {
    this.loadGoogleMaps();
  }
}

loadGoogleMaps() {
  const script = document.createElement('script');
  script.src = `https://maps.googleapis.com/maps/api/js?key=${this.apiKey}`;
  script.async = true;
  script.defer = true;
  script.addEventListener('load', () => this.initMap());
  document.head.appendChild(script);
}
```

**Benefit:** Saves 200-300ms load time on pages without maps.

---

### 4.2 Turbo Frame Partial Updates

**Problem:** Full page reload for minor updates.

**Example: Offer Submission Form**
```erb
<!-- app/views/offers/show.html.erb -->
<%= turbo_frame_tag "offer_form" do %>
  <%= form_with model: @carrier_request, url: offer_path(@carrier_request.token) do |f| %>
    <!-- Form fields -->
  <% end %>
<% end %>
```

**Controller:**
```ruby
def create
  @carrier_request.update(offer_params)

  respond_to do |format|
    format.turbo_stream do
      render turbo_stream: turbo_stream.replace(
        "offer_form",
        partial: "offers/success",
        locals: { carrier_request: @carrier_request }
      )
    end
    format.html { redirect_to offer_path(@carrier_request.token) }
  end
end
```

**Benefit:** Instant feedback, no full page reload.

---

### 4.3 Image Optimization

**Current:** No image optimization (not using images yet).

**Future:** If carrier logos or transport photos added:
- Use WebP format with PNG fallback
- Lazy load images below fold
- Serve responsive sizes via `image_tag` with `srcset`

---

## Monitoring & Measurement

### Metrics to Track

**Application Performance:**
- Average response time (target: < 200ms)
- 90th percentile response time (target: < 500ms)
- Database query time (target: < 50ms average)
- Background job processing time

**Database:**
- Query count per request
- Slow queries (> 100ms)
- Index usage
- Table sizes

**User Experience:**
- Time to First Byte (TTFB)
- Largest Contentful Paint (LCP)
- First Input Delay (FID)
- Cumulative Layout Shift (CLS)

---

### Tools

**Development:**
- `rack-mini-profiler` gem - Query analysis
- `bullet` gem - N+1 query detection
- Rails logs - Query breakdown

**Production:**
- Application Performance Monitoring (APM) - Skylight, AppSignal, or Scout
- Database monitoring - SQLite query logs
- Server monitoring - CPU, memory, disk I/O

---

## Implementation Checklist

### Phase 1: Quick Wins
- [ ] Create migration with missing indexes
- [ ] Run migration in development
- [ ] Measure query time before/after
- [ ] Fix N+1 queries in admin carrier_requests#index
- [ ] Fix N+1 queries in admin transport_requests#index
- [ ] Fix N+1 queries in customer dashboard
- [ ] Add query result caching for static data
- [ ] Deploy to production
- [ ] Monitor for regressions

### Phase 2: Caching
- [ ] Add fragment caching to carrier show page
- [ ] Add fragment caching to transport request show page
- [ ] Add counter caches for carrier_requests
- [ ] Add counter caches for quote_line_items
- [ ] Backfill counter caches
- [ ] Add HTTP caching headers to public pages
- [ ] Test cache expiration
- [ ] Deploy to production

### Phase 3: Algorithm
- [ ] Implement bounding box pre-filter
- [ ] Test matching accuracy (should match same carriers)
- [ ] Measure performance improvement
- [ ] Add distance calculation memoization
- [ ] Consider matching result caching (optional)
- [ ] Deploy to production

### Phase 4: Frontend
- [ ] Implement lazy loading for Google Maps
- [ ] Convert offer form to Turbo Frame
- [ ] Test on slow connections
- [ ] Deploy to production

---

## Risk Assessment

### Low Risk
✅ Adding indexes (non-breaking, easily reversible)
✅ Fragment caching (automatic expiration)
✅ N+1 query fixes with `includes` (transparent to users)

### Medium Risk
⚠️ Counter caches (requires data backfill, can drift if not maintained)
⚠️ Query result caching (stale data risk)
⚠️ Bounding box filter (edge cases near poles, could miss carriers)

### High Risk
🔴 Matching result caching (may miss newly added carriers)
🔴 Aggressive HTTP caching (stale data shown to users)

---

## Rollback Plan

If performance optimization causes issues:

1. **Indexes:** Safe to remove (no data loss)
   ```bash
   rails generate migration RemovePerformanceIndexes
   # In migration: remove_index :table, :column
   ```

2. **N+1 Fixes:** Revert code changes (git)
   ```bash
   git revert <commit-hash>
   ```

3. **Caching:** Flush cache and disable
   ```bash
   rails cache:clear
   # Comment out cache blocks
   ```

4. **Counter Caches:** Remove columns, stop using
   ```bash
   rails generate migration RemoveCounterCaches
   # Switch back to .count method
   ```

---

## Success Criteria

**Phase 1 Complete When:**
- [ ] All foreign keys have indexes
- [ ] Zero N+1 queries in admin/customer dashboards
- [ ] Average query time < 50ms
- [ ] List pages load in < 200ms

**Phase 2 Complete When:**
- [ ] Fragment cache hit rate > 80%
- [ ] Counter caches accurate and maintained
- [ ] Static data cached for 1 hour+

**Phase 3 Complete When:**
- [ ] Matching algorithm < 50ms for 100 carriers
- [ ] Bounding box filter reduces calculations by 80%+

**Phase 4 Complete When:**
- [ ] Google Maps loads only on pages with maps
- [ ] Turbo Frames used for forms
- [ ] Perceived load time improved

---

## Related Documentation

- **[Project Architecture](../System/project_architecture.md)** - Current performance status
- **[Database Schema](../System/database_schema.md)** - Index opportunities
- **[Carrier Matching Algorithm](../System/carrier_matching_algorithm.md)** - Algorithm bottlenecks
- **Rails Guides:** [Caching with Rails](https://guides.rubyonrails.org/caching_with_rails.html)
- **Rails Guides:** [Active Record Query Interface](https://guides.rubyonrails.org/active_record_querying.html)

---

## Version History

| Date | Change | Author |
|------|--------|--------|
| 2025-10-08 | Initial roadmap created | Claude Code |

---

**Last Review:** 2025-10-08
**Next Review Due:** When performance triggers are met
