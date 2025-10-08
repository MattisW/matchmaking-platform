# System Documentation Implementation Plan

**Created:** 2025-10-08
**Status:** In Progress
**Priority:** High
**Related Docs:** [.agent/README.md](../README.md)

---

## Overview

Complete the `.agent/` documentation structure by creating comprehensive system architecture documentation. This follows the project's philosophy of maintaining up-to-date documentation after feature implementation.

## Background

### Current State
- ✅ `.agent/` structure created
- ✅ 1 SOP exists (Quote System Implementation)
- ✅ README.md index created but references missing docs
- ❌ No system architecture documentation
- ❌ No database schema documentation
- ❌ No authentication/authorization documentation

### Why Now?
1. System is feature-complete enough to document
2. Code is fresh in memory (just fixed bugs, implemented features)
3. Sets foundation for future developers
4. Follows project guidance: "We should always update .agent docs after we implement certain feature"

---

## Goals

### Primary Objectives
1. ✅ New developers can understand system from docs alone
2. ✅ All major architectural decisions documented
3. ✅ Database schema fully explained with relationships
4. ✅ Authentication patterns clearly documented
5. ✅ Core algorithms (matching) explained

### Success Metrics
- [ ] All "Coming Soon" items in README.md completed
- [ ] Each system doc includes examples and code references
- [ ] No contradictions between docs
- [ ] All docs committed to git

---

## Deliverables

### 1. `.agent/System/project_architecture.md`
**Purpose:** High-level system overview

**Sections:**
- Project Overview
  - Business domain (logistics matchmaking)
  - Current status & completion level
- Architecture Decisions
  - Monolith-first approach
  - No build step philosophy
  - Rails conventions over configuration
- Tech Stack
  - Backend (Rails 8, SQLite, Devise, Geocoder)
  - Frontend (Hotwire, Tailwind, Stimulus)
  - Infrastructure (Solid Queue, Kamal)
- User & Role Architecture
  - Admin/Dispatcher (full access)
  - Customer (self-service)
  - Carrier (email-based, no auth)
- Integration Points
  - Google Maps API
  - Geocoder gem
  - Email (Resend in production)
- File Structure
  - MVC organization
  - Namespaces (admin, customer)
  - Service objects (lib/)
- Key Design Patterns
  - Service objects for business logic
  - Stimulus controllers for interactivity
  - Nested attributes for complex forms

---

### 2. `.agent/System/database_schema.md`
**Purpose:** Complete database reference

**Sections:**
- ER Diagram (text-based representation)
- Core Tables
  - **users** (Devise + roles)
    - Fields: email, role, company_name, locale
    - Relationships: has_many transport_requests
  - **carriers** (no authentication)
    - Fields: company info, location, fleet, equipment
    - Relationships: has_many carrier_requests
  - **transport_requests** (main entity)
    - Fields: addresses, dates, cargo, status
    - Relationships: belongs_to user, has_many carrier_requests, has_one quote
  - **carrier_requests** (offers)
    - Fields: distances, offer details, status
    - Relationships: belongs_to carrier, belongs_to transport_request
  - **quotes** + **quote_line_items**
    - Fields: pricing, status, timestamps
    - Relationships: belongs_to transport_request, has_many line_items
  - **pricing_rules**
    - Fields: vehicle_type, rates, surcharges
  - **package_items** + **package_type_presets**
    - Fields: dimensions, weight, type
- Relationships Map
  - belongs_to associations
  - has_many / has_one associations
  - Inverse relationships
- Indexes
  - Existing indexes
  - Missing indexes (performance opportunities)
- Serialized Fields
  - pickup_countries (JSON array in SQLite)
  - delivery_countries (JSON array in SQLite)
- Status Enums
  - TransportRequest statuses
  - Quote statuses
  - CarrierRequest statuses

---

### 3. `.agent/System/authentication_authorization.md`
**Purpose:** Security & access control documentation

**Sections:**
- Devise Configuration
  - Modules used (database_authenticatable, registerable, etc.)
  - Password requirements
  - Session management
- Role System
  - String-based roles (admin, dispatcher, customer)
  - Role helper methods (admin?, customer?, etc.)
  - Default role (dispatcher)
- Authorization
  - Controller filters (ensure_admin!, ensure_customer!)
  - Layout routing by role
  - Route constraints
- Carrier Access Pattern
  - No authentication for carriers
  - Token-based public URLs
  - Email workflow instead of login
- Session Flow
  - Login process
  - Role detection
  - Layout assignment
  - Locale setting

---

### 4. `.agent/System/carrier_matching_algorithm.md`
**Purpose:** Core business logic documentation

**Sections:**
- Algorithm Overview
  - Purpose: Match carriers to transport requests
  - Location: `lib/matching/algorithm.rb`
  - Trigger: Manual (admin) or automatic (customer)
- Filtering Pipeline
  1. **Vehicle Type Filter**
     - Match transporter vs LKW requirements
     - Cargo capacity checks
  2. **Geographic Coverage Filter**
     - Pickup country in carrier's pickup_countries
     - Delivery country in carrier's delivery_countries
  3. **Service Radius Filter**
     - Calculate distance from carrier to pickup location
     - Compare against carrier's pickup_radius_km
     - Haversine formula for accuracy
  4. **Capacity Filter** (if LKW)
     - Check cargo dimensions against vehicle dimensions
  5. **Equipment Filter**
     - Liftgate, pallet jack, GPS tracking requirements
- Distance Calculator
  - Haversine formula implementation
  - Why not use Geocoder's distance (precision for radius filtering)
  - Location: `lib/matching/distance_calculator.rb`
- Job Flow
  1. User triggers matching (manual or auto)
  2. `MatchCarriersJob` runs algorithm
  3. Creates `CarrierRequest` records for matches
  4. `SendCarrierInvitationsJob` sends emails
  5. Carriers receive unique offer links
- Data Flow
  - Input: TransportRequest with geocoded addresses
  - Process: Multi-filter matching
  - Output: CarrierRequest records with calculated distances

---

### 5. `.agent/SOP/adding_database_migrations.md`
**Purpose:** Guide for safe schema changes

**Sections:**
- When to Create a Migration
  - New models
  - Schema changes
  - Data migrations
- Naming Conventions
  - Descriptive names (AddFieldToTable, CreateTableName)
  - Timestamp-based ordering
- Migration Types
  - Adding columns
  - Removing columns
  - Changing column types
  - Adding indexes
  - Data migrations
- SQLite Considerations
  - Serialized arrays (JSON text columns)
  - No native array type
  - Foreign key constraints
- Testing Migrations
  - Run in development first
  - Check schema.rb diff
  - Test rollback
  - Verify data integrity
- Common Patterns
  ```ruby
  # Adding indexed foreign key
  add_reference :table, :other_table, foreign_key: true, index: true

  # Adding serialized array
  add_column :table, :field, :text
  # In model: serialize :field, coder: JSON, type: Array

  # Adding enum-like string
  add_column :table, :status, :string, default: 'pending', null: false
  add_index :table, :status
  ```
- Rollback Safety
  - Always implement `down` method or use `change`
  - Test rollback before committing
  - Never delete columns with data in production

---

### 6. `.agent/Tasks/performance_optimization.md`
**Purpose:** Future performance improvements roadmap

**Sections:**
- Database Optimization
  - **Missing Indexes**
    - Foreign keys without indexes
    - Status columns for filtering
    - Timestamp columns for ordering
  - **Query Optimization**
    - N+1 query locations
    - Eager loading strategies (.includes)
    - Counter caches for counts
- Caching Strategy
  - Static data (package presets, pricing rules)
  - Fragment caching for lists
  - Query result caching
- Background Job Optimization
  - Batch processing for emails
  - Job priority queues
  - Retry strategies
- Frontend Performance
  - Lazy loading for maps
  - Image optimization
  - Turbo Frame usage

---

### 7. Update `.agent/README.md`
**Changes:**
- Mark all system docs as complete (remove "Coming Soon")
- Update quick start guide
- Add links to all new documentation
- Update last modified date
- Increment version history

---

## Implementation Order

1. ✅ Save this plan to `.agent/Tasks/system_documentation_plan.md`
2. 📝 Create `project_architecture.md` (foundation)
3. 📝 Create `database_schema.md` (reference)
4. 📝 Create `authentication_authorization.md` (security)
5. 📝 Create `carrier_matching_algorithm.md` (core logic)
6. 📝 Create `adding_database_migrations.md` (SOP)
7. 📝 Create `performance_optimization.md` (roadmap)
8. 📝 Update `.agent/README.md` (index)
9. ✅ Commit all to git

---

## Acceptance Criteria

- [ ] All planned files created with comprehensive content
- [ ] Each doc includes code examples and file references
- [ ] Cross-references between docs are accurate
- [ ] README.md index updated with all new docs
- [ ] No "Coming Soon" placeholders for completed items
- [ ] Git commit with descriptive message
- [ ] All docs reviewed for accuracy and consistency

---

## Related Files & References

**Existing Documentation:**
- `CLAUDE.md` - Main project guide
- `.agent/README.md` - Documentation index
- `.agent/SOP/quote_system_implementation.md` - Example SOP

**Code References:**
- `db/schema.rb` - Current database schema
- `app/models/` - All model definitions
- `lib/matching/algorithm.rb` - Matching logic
- `config/routes.rb` - Route definitions
- `app/controllers/application_controller.rb` - Auth setup

**External Resources:**
- Rails Guides: https://guides.rubyonrails.org/
- Devise Wiki: https://github.com/heartcombo/devise/wiki
- Hotwire Docs: https://hotwired.dev/

---

## Estimated Effort

- Research & code review: 30 minutes
- Writing documentation: 2-3 hours
- Review & editing: 15 minutes
- **Total: ~3 hours**

---

## Notes

- Focus on clarity over exhaustiveness
- Include practical examples from actual codebase
- Cross-reference related docs
- Keep consistent formatting across all docs
- This documentation will serve as onboarding material for new developers
