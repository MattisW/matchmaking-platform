# .agent Documentation Index

**Last Updated:** 2025-10-08

This directory contains all critical documentation for the Matchmaking Platform project. Use this index to quickly find the information you need.

---

## Quick Start

**New to the project?** Read in this order:
1. [Project Architecture](./System/project_architecture.md) *(coming soon)*
2. [Database Schema](./System/database_schema.md) *(coming soon)*
3. [Quote System SOP](./SOP/quote_system_implementation.md)

---

## Documentation Structure

### 📋 Standard Operating Procedures (SOP)

**Purpose:** Step-by-step guides for implementing specific features or performing common tasks.

| Document | Description | Last Updated |
|----------|-------------|--------------|
| [Quote System Implementation](./SOP/quote_system_implementation.md) | Complete guide to implementing automated quote generation and pricing calculator | 2025-10-08 |

**Coming Soon:**
- `adding_database_migrations.md` - How to safely add new database migrations
- `implementing_new_controller.md` - Controller patterns and conventions
- `adding_localization.md` - How to add new languages or translations
- `deployment_checklist.md` - Pre-deployment verification steps

### 🏗️ System Architecture & Design (System)

**Purpose:** High-level system documentation, architecture decisions, tech stack, and integration points.

| Document | Description | Status |
|----------|-------------|--------|
| `project_architecture.md` | Overall project structure, tech stack, and architectural decisions | Coming Soon |
| `database_schema.md` | Complete database schema with relationships and indexes | Coming Soon |
| `authentication_flow.md` | User authentication and authorization (Devise, roles) | Coming Soon |
| `carrier_matching_algorithm.md` | How carrier matching works | Coming Soon |

### 📝 Tasks & Feature Plans (Tasks)

**Purpose:** Product requirements and implementation plans for features (past and future).

| Document | Description | Status |
|----------|-------------|--------|
| `quote_system_prd.md` | Product requirements for quote & pricing system | Coming Soon |
| `cargo_management_prd.md` | Product requirements for package/loading meter management | Coming Soon |
| `customer_portal_prd.md` | Requirements for customer self-service portal | Coming Soon |

---

## Feature Implementation Status

### ✅ Completed Features

- **User Authentication & Authorization**
  - Devise-based authentication
  - Role-based access (admin, dispatcher, customer)
  - Layout routing by role

- **Carrier Management**
  - CRUD operations for carriers
  - Geographic coverage configuration
  - Fleet and equipment tracking
  - Rating system

- **Transport Request Management**
  - Google Maps autocomplete for addresses
  - Detailed address fields (company, street, postal code, etc.)
  - Package items with type presets
  - Loading meters mode
  - Vehicle booking mode
  - Date/time pickers with 15-min increments

- **Quote & Pricing System** 📍 *[SOP](./SOP/quote_system_implementation.md)*
  - Automated quote generation
  - Configurable pricing rules per vehicle type
  - Weekend and express surcharges
  - Quote acceptance/decline workflow

- **Carrier Matching**
  - Algorithm-based matching
  - Email invitations to carriers
  - Public offer submission forms

- **Customer Portal**
  - Self-service transport request creation
  - Quote review and acceptance
  - Request status tracking

- **Localization**
  - English and German support
  - User-specific locale preferences
  - Language switcher in UI

### 🚧 In Progress

- Documentation completion
- Automated testing suite

### 📋 Planned Features

- Multi-tenancy (Company model)
- Advanced analytics dashboard
- Real-time notifications
- Mobile responsive enhancements
- API endpoints for third-party integrations

---

## Technology Stack

### Backend
- **Framework:** Ruby on Rails 8.0+
- **Database:** SQLite (development, test, production)
- **Authentication:** Devise
- **Background Jobs:** Solid Queue
- **Geocoding:** Geocoder gem + Google Maps API
- **Email:** ActionMailer (Resend in production)

### Frontend
- **JavaScript:** Hotwire (Turbo + Stimulus)
- **CSS:** Tailwind CSS
- **Maps:** Google Maps JavaScript API
- **Module Loading:** Importmap (no build step)

### Deployment
- **Platform:** Kamal 2 to VPS
- **Server:** Puma
- **Caching:** Solid Cache

---

## Key Conventions

### File Naming
- Models: Singular, CamelCase (`TransportRequest`)
- Controllers: Plural, CamelCase with namespaces (`Admin::TransportRequestsController`)
- Files: snake_case (`transport_requests_controller.rb`)
- Views: snake_case (`_quote_card.html.erb`)

### Database
- Tables: Plural, snake_case (`transport_requests`)
- Foreign keys: Singular with `_id` suffix (`user_id`)
- Timestamps: Always include `created_at` and `updated_at`

### Routes
- Use RESTful routes with `resources`
- Namespace by role (`admin`, `customer`)
- Custom actions as member/collection routes

### Code Style
- 2-space indentation
- Follow Ruby Style Guide
- Fat models, skinny controllers
- Service objects in `lib/` for complex business logic

---

## Common Tasks Quick Reference

### Add a New Model

```bash
rails generate model ModelName field1:type field2:type
rails db:migrate
```

### Add a New Controller

```bash
rails generate controller Namespace::ControllerName action1 action2
```

### Add a Stimulus Controller

```bash
rails generate stimulus ControllerName
```

### Add Translations

Edit `config/locales/en.yml` and `config/locales/de.yml`:
```yaml
en:
  feature:
    key: "Value"
```

### Run Background Job

```ruby
JobName.perform_later(arg1, arg2)
```

### Check Routes

```bash
rails routes | grep pattern
```

---

## Development Workflow

### Starting the App

```bash
# Terminal 1: Rails server
rails server

# Terminal 2: Tailwind CSS watcher
rails tailwindcss:watch
```

### Database Operations

```bash
rails db:migrate          # Run pending migrations
rails db:rollback         # Rollback last migration
rails db:seed             # Seed database
rails db:reset            # Drop, create, migrate, seed
rails db:migrate:status   # Check migration status
```

### Console Access

```bash
rails console             # Development console
rails console -e production  # Production console
```

---

## Getting Help

### Documentation Locations

1. **This directory (`.agent/`)** - Project-specific docs
2. **Main `CLAUDE.md`** - High-level project guide
3. **`IMPLEMENTATION_GUIDE.md`** - Feature implementation details
4. **`THEME_STATUS.md`** - UI/theme system status

### External Resources

- [Rails Guides](https://guides.rubyonrails.org/)
- [Hotwire Documentation](https://hotwired.dev/)
- [Tailwind CSS Docs](https://tailwindcss.com/docs)
- [Devise Wiki](https://github.com/heartcombo/devise/wiki)

---

## Contributing to Documentation

### When to Update Docs

- ✅ After implementing a new feature
- ✅ After fixing a critical bug
- ✅ When you find outdated information
- ✅ When you discover a better way to do something
- ✅ When adding new conventions or patterns

### Documentation Standards

1. **SOPs:** Should be step-by-step, actionable guides
2. **System Docs:** Should explain *why* and *how* things work
3. **Task Docs:** Should include requirements, acceptance criteria, and implementation plan
4. **Always update this README** when adding new docs

### Creating New Documentation

Use this template:

```markdown
# Document Title

**Last Updated:** YYYY-MM-DD
**Author:** Your Name
**Related Docs:** List related docs with links

---

## Overview
Brief description

## [Sections based on doc type]

---

## Related Files
List relevant code files
```

---

## Contact & Support

**Questions?** Ask in the team Slack channel or create a GitHub issue.

**Found a bug in docs?** Open a PR with the fix.

**Want to add documentation?** Follow the template above and submit a PR.

---

## Version History

| Date | Changes | Author |
|------|---------|--------|
| 2025-10-08 | Created initial README and Quote System SOP | Claude Code |

---

**Last Review:** 2025-10-08
**Next Review Due:** 2025-11-08
