# Project Architecture

**Last Updated:** 2025-10-08
**Related Docs:** [Database Schema](./database_schema.md), [Authentication](./authentication_authorization.md), [.agent README](../README.md)

---

## Project Overview

### Business Domain
The **Logistics Matchmaking Platform** is a Rails 8 application that connects shippers (customers) with carriers through intelligent, algorithm-based matching. The platform automates the process of finding suitable carriers based on:
- Geographic proximity
- Vehicle capabilities
- Cargo requirements
- Equipment availability
- Service coverage areas

### Current Status
**Stage:** MVP Complete
**Environment:** Development + Production-ready
**Deployment:** Kamal 2 to VPS

**Key Features:**
- ✅ Customer self-service portal
- ✅ Admin management interface
- ✅ Automated carrier matching
- ✅ Quote generation & pricing
- ✅ Email-based carrier workflow
- ✅ Google Maps integration
- ✅ Multi-language support (EN/DE)

---

## Architecture Decisions

### 1. Monolith-First Approach

**Decision:** Build as a full-stack Rails monolith, not separate API + frontend

**Rationale:**
- Faster development velocity
- Simpler deployment
- Easier to reason about
- Can extract services later if needed
- Hotwire provides modern UX without SPA complexity

**When to Revisit:**
- When horizontal scaling is needed (multiple app servers)
- If mobile app or third-party integrations require dedicated API
- When team size justifies microservices complexity

### 2. No Build Step Philosophy

**Decision:** No Node.js, npm, webpack, or JavaScript bundlers

**Implementation:**
- **JavaScript:** Importmap for module loading
- **CSS:** Tailwind via `tailwindcss:watch` command
- **Assets:** Propshaft (Rails 8 default)

**Benefits:**
- Zero configuration complexity
- Faster boot times
- Pure Rails development experience
- No version conflicts between Node/Ruby tooling

**Tradeoffs:**
- Limited access to npm ecosystem
- Can't use React/Vue (using Hotwire instead)
- Some modern JS features require polyfills

### 3. SQLite for Production

**Decision:** Use SQLite for development, test, AND production

**Rationale:**
- Rails 8 production-ready SQLite optimizations
- Simpler than PostgreSQL for this scale
- File-based backups (no separate DB server)
- Faster read operations
- Zero hosting cost for database

**Limits:**
- Write concurrency (handled by Solid Queue for jobs)
- No native array/JSONB types (using JSON-serialized text)
- Single-server architecture (for now)

**When to Switch to PostgreSQL:**
- Database exceeds 1GB
- Need horizontal scaling
- Require PostgreSQL-specific features
- Write concurrency becomes bottleneck

### 4. Convention Over Configuration

**Decision:** Strictly follow Rails conventions

**Examples:**
- RESTful routes (`resources :carriers`)
- Model naming (singular: `Carrier`, table: `carriers`)
- File structure (MVC)
- Naming patterns (`Admin::CarriersController`)

**Philosophy:**
- "Make it work, then make it good, then make it fast"
- "Optimize for developer happiness"
- Embrace Rails magic, don't fight it

---

## Technology Stack

### Backend

| Technology | Version | Purpose |
|------------|---------|---------|
| **Ruby on Rails** | 8.0+ | Full-stack framework |
| **Ruby** | 3.4+ | Language |
| **SQLite** | 3.x | Database (dev/test/prod) |
| **Devise** | Latest | Authentication |
| **Geocoder** | Latest | Geocoding + distance |
| **Solid Queue** | Rails 8 | Background jobs (no Redis) |
| **Solid Cache** | Rails 8 | Caching (no Redis) |
| **Puma** | Rails default | Web server |

### Frontend

| Technology | Purpose |
|------------|---------|
| **Hotwire (Turbo + Stimulus)** | Interactivity without React |
| **Tailwind CSS** | Utility-first styling |
| **Importmap** | JavaScript module loading |
| **Google Maps JavaScript API** | Maps & autocomplete |
| **Propshaft** | Asset pipeline (Rails 8) |

### External Services

| Service | Purpose | Environment |
|---------|---------|-------------|
| **Google Maps API** | Geocoding, autocomplete, maps | All |
| **Resend** | Email delivery | Production |
| **Letter Opener** | Email preview | Development |

### Deployment

| Technology | Purpose |
|------------|---------|
| **Kamal 2** | Container orchestration |
| **Docker** | Containerization |
| **VPS** | Hosting (Hetzner/DigitalOcean) |

---

## User & Role Architecture

### Three User Types

#### 1. Admin / Dispatcher (`role='admin'` or `role='dispatcher'`)
**Database:** User record
**Authentication:** Yes (Devise)
**Access Level:** Full platform access

**Capabilities:**
- Manage carriers (CRUD)
- Manage all transport requests (any customer)
- Run matching algorithm
- Accept/reject offers on behalf of customers
- View all system activity
- Configure pricing rules

#### 2. Customer (`role='customer'`)
**Database:** User record
**Authentication:** Yes (Devise)
**Access Level:** Own data only

**Capabilities:**
- Create transport requests
- View own requests only
- Review quotes
- Accept/decline quotes
- Track shipment status
- **Cannot** access admin features

#### 3. Carrier (NOT a User)
**Database:** Carrier record (separate table)
**Authentication:** NO
**Access Level:** Email-based, token URLs

**Capabilities:**
- Receive email invitations
- Submit offers via public forms
- Receive acceptance/rejection notifications
- **No login, no password, no session**

### Why Carriers Aren't Users

**Design Decision:** Carriers are database records, not authenticated users

**Rationale:**
1. **Simplicity:** No onboarding friction, no password management
2. **Natural Workflow:** B2B logistics works via email
3. **Minimal Features:** Carriers only submit offers (one action)
4. **Security:** Unique tokens in URLs provide sufficient access control
5. **Scale:** No account management overhead

**Implementation:**
- CarrierRequest has unique token for offer form access
- Emails contain link: `/offers/{token}/submit`
- No session, no cookies, no authentication
- One-time use tokens

---

## Integration Points

### Google Maps API

**Purpose:** Geocoding, autocomplete, route visualization

**Components:**
1. **Geocoding** (via Geocoder gem)
   - Convert addresses to lat/lon
   - Extract country codes
   - Calculate distances

2. **Autocomplete** (JavaScript API)
   - Stimulus controller: `autocomplete_controller.js`
   - Real-time address suggestions
   - Auto-populates hidden fields (lat, lon, country)

3. **Map Display** (JavaScript API)
   - Stimulus controller: `map_controller.js`
   - Shows pickup → delivery route
   - Markers for start/end points

**Configuration:**
- API key in `config/credentials.yml.enc`
- Exposed via meta tag in layouts
- Loaded dynamically in Stimulus controllers

### Geocoder Gem

**Purpose:** Server-side geocoding, distance calculations

**Usage:**
```ruby
# Geocode address
result = Geocoder.search('Berlin, Germany').first
result.latitude  # => 52.520008
result.longitude # => 13.404954

# Calculate distance
Geocoder::Calculations.distance_between(
  [lat1, lon1], [lat2, lon2]
) # => km
```

**Providers:**
- Primary: Google Geocoding API
- Configured in `config/initializers/geocoder.rb`

### Email System

**Development:**
- **Letter Opener** gem
- Emails open in browser automatically
- No actual delivery

**Production:**
- **Resend** API
- Configured via ENV variables
- Action Mailer SMTP settings

**Email Types:**
- Carrier invitations (DE/EN)
- Offer accepted/rejected notifications
- System alerts (future)

---

## File Structure

### MVC Organization

```
app/
├── controllers/
│   ├── admin/                    # Admin namespace
│   │   ├── carriers_controller.rb
│   │   ├── transport_requests_controller.rb
│   │   ├── carrier_requests_controller.rb
│   │   └── pricing_rules_controller.rb
│   ├── customer/                 # Customer namespace
│   │   ├── base_controller.rb   # Shared customer auth
│   │   ├── dashboard_controller.rb
│   │   ├── transport_requests_controller.rb
│   │   └── quotes_controller.rb
│   ├── offers_controller.rb     # Public (no auth)
│   └── application_controller.rb
├── models/
│   ├── user.rb                  # Devise + roles
│   ├── carrier.rb              # No auth
│   ├── transport_request.rb
│   ├── carrier_request.rb
│   ├── quote.rb
│   ├── quote_line_item.rb
│   └── pricing_rule.rb
├── views/
│   ├── layouts/
│   │   ├── admin.html.erb      # Gray sidebar
│   │   ├── customer.html.erb   # Blue sidebar
│   │   ├── application.html.erb # Public
│   │   └── devise.html.erb     # Auth pages
│   ├── admin/                   # Admin views
│   ├── customer/                # Customer views
│   └── offers/                  # Public forms
└── javascript/
    └── controllers/             # Stimulus
        ├── autocomplete_controller.js
        ├── map_controller.js
        ├── package_items_controller.js
        └── shipping_mode_controller.js
```

### Service Objects (`lib/`)

```
lib/
├── matching/
│   ├── algorithm.rb            # Core matching logic
│   └── distance_calculator.rb  # Haversine formula
└── pricing/
    └── calculator.rb            # Quote generation
```

**Pattern:**
- POROs (Plain Old Ruby Objects)
- Single responsibility
- Testable in isolation
- Called from controllers/jobs

**Example:**
```ruby
# lib/pricing/calculator.rb
module Pricing
  class Calculator
    def initialize(transport_request)
      @transport_request = transport_request
    end

    def calculate
      # Business logic here
    end
  end
end

# Usage in controller
calc = Pricing::Calculator.new(@request)
quote = calc.calculate
```

### Background Jobs

```
app/jobs/
├── application_job.rb
├── match_carriers_job.rb         # Run matching
└── send_carrier_invitations_job.rb # Email carriers
```

**Execution:**
- Solid Queue (Rails 8, no Redis)
- Async processing
- Retry logic built-in

---

## Key Design Patterns

### 1. Service Objects

**When:** Complex business logic that doesn't belong in models/controllers

**Examples:**
- `Pricing::Calculator` - Quote generation
- `Matching::Algorithm` - Carrier matching
- `Matching::DistanceCalculator` - Haversine distance

**Structure:**
```ruby
module Namespace
  class ServiceName
    def initialize(params)
      # Setup
    end

    def call
      # Main logic
    end

    private
    # Helper methods
  end
end
```

### 2. Stimulus Controllers

**When:** Interactive UI components

**Examples:**
- Address autocomplete
- Map display
- Package item dynamic forms
- Shipping mode tabs

**Pattern:**
```javascript
// app/javascript/controllers/example_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "output"]
  static values = { url: String }

  connect() {
    // Initialize
  }

  action() {
    // Handle event
  }
}
```

**Usage in View:**
```erb
<div data-controller="example"
     data-example-url-value="<%= some_path %>">
  <input data-example-target="input">
  <div data-example-target="output"></div>
</div>
```

### 3. Nested Attributes

**When:** Complex forms with has_many relationships

**Example:** Transport Request with Package Items

**Model:**
```ruby
class TransportRequest < ApplicationRecord
  has_many :package_items, dependent: :destroy
  accepts_nested_attributes_for :package_items,
                                allow_destroy: true,
                                reject_if: :all_blank
end
```

**Controller:**
```ruby
def transport_request_params
  params.require(:transport_request).permit(
    :field1, :field2,
    package_items_attributes: [:id, :field, :_destroy]
  )
end
```

**View:**
```erb
<%= form_with model: @request do |f| %>
  <%= f.fields_for :package_items do |item_form| %>
    <%= render 'package_item_fields', f: item_form %>
  <% end %>
<% end %>
```

### 4. Namespaced Routes & Controllers

**Purpose:** Separate admin and customer interfaces

**Routes:**
```ruby
namespace :admin do
  resources :carriers
  resources :transport_requests
end

namespace :customer do
  resources :transport_requests
  resource :dashboard, only: [:show]
end
```

**Controllers:**
```ruby
# app/controllers/admin/carriers_controller.rb
module Admin
  class CarriersController < ApplicationController
    before_action :ensure_admin!
    layout "admin"
    # ...
  end
end
```

### 5. Inverse Associations

**Purpose:** Prevent validation errors in nested records

**Pattern:**
```ruby
class Quote < ApplicationRecord
  has_many :quote_line_items,
           dependent: :destroy,
           inverse_of: :quote  # ← Critical
end

class QuoteLineItem < ApplicationRecord
  belongs_to :quote,
             inverse_of: :quote_line_items  # ← Critical
end
```

**Why:** Without `inverse_of`, Rails can't link parent/child before save, causing validation failures.

---

## Data Flow

### Transport Request Creation (Customer)

```
1. Customer fills form → Google autocomplete populates address
2. Hidden fields store lat/lon/country
3. Form submits to CustomerTransportRequestsController#create
4. Geocoding happens (if needed)
5. TransportRequest saved
6. Pricing::Calculator generates quote
7. Quote saved
8. Redirect to show page with quote card
```

### Quote Acceptance Flow

```
1. Customer clicks "Accept Quote" button
2. POST to customer_transport_request_quote_accept_path
3. Quote.accept! (status → accepted, triggers timestamp)
4. TransportRequest.status → quote_accepted
5. MatchCarriersJob.perform_later (background)
6. Algorithm finds matching carriers
7. CarrierRequest records created
8. SendCarrierInvitationsJob.perform_later
9. Emails sent to all matched carriers
10. Redirect with success message
```

### Carrier Offer Submission

```
1. Carrier receives email with unique token link
2. Clicks link → OffersController#show (public, no auth)
3. Form displays with CarrierRequest details
4. Carrier fills price, delivery date, notes
5. Submit → OffersController#create
6. CarrierRequest updated (status → offered)
7. Confirmation page shown
8. Customer sees offer in dashboard
```

---

## Security Architecture

### Authentication
- **Devise** for users (admin, dispatcher, customer)
- **No auth** for carriers (token-based access)

### Authorization
- **Before actions** on controllers
- **Layout routing** by role
- **Route constraints** for root path

### Data Isolation
- **Admins:** See all data
- **Customers:** See only own transport requests
- **Carriers:** Access via unique tokens only

**Implementation:**
```ruby
# Scoping in customer controllers
@requests = current_user.transport_requests

# vs admin controllers
@requests = TransportRequest.all
```

---

## Performance Considerations

### Current Optimizations
- ✅ Geocoding cached in database
- ✅ Distance pre-calculated and stored
- ✅ Includes for N+1 prevention (partial)
- ✅ Background jobs for heavy operations

### Known Performance Gaps
- ❌ Missing indexes on foreign keys
- ❌ Some N+1 queries in list views
- ❌ No fragment caching
- ❌ No counter caches

**See:** [Performance Optimization Task](../Tasks/performance_optimization.md) for details

---

## Deployment Architecture

### Development
```
Rails server (port 3000)
↓
SQLite database (storage/development.sqlite3)
Letter Opener (email preview)
```

### Production (Kamal 2)
```
VPS (Hetzner/DigitalOcean)
↓
Docker container (Rails app)
↓
SQLite database (mounted volume)
Solid Queue (background jobs)
Resend (email delivery)
```

**Kamal Features:**
- Zero-downtime deployments
- Automatic SSL (Let's Encrypt)
- Container health checks
- Log aggregation

---

## Scalability Path

### Current Capacity
- **Users:** 100-1000
- **Requests:** 1000-10000
- **Database:** < 1GB

### When to Scale

**Vertical (Upgrade Server):**
- CPU usage > 80% sustained
- Memory usage > 80%
- Response times > 500ms

**Horizontal (Add Servers):**
- Need high availability
- Geographic distribution
- Load > single server capacity

**Database Migration:**
- SQLite > 1GB
- Write concurrency issues
- Need PostgreSQL features

### Migration Path
1. Add database indexes (quick win)
2. Implement caching (Solid Cache)
3. Optimize N+1 queries
4. Add CDN for static assets
5. Multiple app servers (need PostgreSQL)
6. Extract microservices (if needed)

---

## Testing Strategy

### Current Approach
**Manual testing only** (per CLAUDE.md philosophy)

**Why:**
- Faster development for MVP
- Tests deferred until product validated
- Focus on shipping features

### Future Testing
When ready to add tests:
- **Models:** RSpec for business logic
- **Controllers:** Request specs for HTTP
- **System:** Capybara for end-to-end
- **Services:** Unit tests for calculators

**Priority Order:**
1. Service objects (Pricing::Calculator, Matching::Algorithm)
2. Models with complex validations
3. Controllers (request specs)
4. System tests (smoke tests only)

---

## Related Documentation

- **[Database Schema](./database_schema.md)** - Complete schema reference
- **[Authentication & Authorization](./authentication_authorization.md)** - Security details
- **[Carrier Matching Algorithm](./carrier_matching_algorithm.md)** - Core business logic
- **[Quote System SOP](../SOP/quote_system_implementation.md)** - Implementation guide
- **[.agent README](../README.md)** - Documentation index

---

## Maintenance & Evolution

### Regular Reviews
- **Monthly:** Review performance metrics
- **Quarterly:** Re-evaluate tech stack decisions
- **Annually:** Assess architecture for scale needs

### Decision Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2025-10-05 | SQLite for production | Rails 8 support, simpler ops |
| 2025-10-06 | No carrier authentication | Email workflow sufficient |
| 2025-10-08 | Quote system before matching | Better UX for customers |

---

**Last Review:** 2025-10-08
**Next Review Due:** 2025-11-08
