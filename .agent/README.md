# .agent Documentation Index

**Last Updated:** 2025-10-08

This directory contains all critical documentation for the Matchmaking Platform project. Use this index to quickly find the information you need.

---

## Quick Start

**New to the project?** Read in this order:
1. [Project Architecture](./System/project_architecture.md)
2. [Database Schema](./System/database_schema.md)
3. [Authentication & Authorization](./System/authentication_authorization.md)
4. [Quote System SOP](./SOP/quote_system_implementation.md)

---

## Documentation Structure

### 📋 Standard Operating Procedures (SOP)

**Purpose:** Step-by-step guides for implementing specific features or performing common tasks.

| Document | Description | Last Updated |
|----------|-------------|--------------|
| [Quote System Implementation](./SOP/quote_system_implementation.md) | Complete guide to implementing automated quote generation and pricing calculator | 2025-10-08 |
| [Adding Database Migrations](./SOP/adding_database_migrations.md) | Step-by-step guide for creating safe, reversible database migrations in SQLite | 2025-10-08 |
| [Implementing Multi-Mode Cargo Management](./SOP/implementing_multi_mode_cargo_management.md) | Comprehensive guide to building multi-mode interfaces with nested forms, Stimulus controllers, and theme variations | 2025-10-08 |

**Coming Soon:**
- `implementing_new_controller.md` - Controller patterns and conventions
- `adding_localization.md` - How to add new languages or translations
- `deployment_checklist.md` - Pre-deployment verification steps

### 🏗️ System Architecture & Design (System)

**Purpose:** High-level system documentation, architecture decisions, tech stack, and integration points.

| Document | Description | Last Updated |
|----------|-------------|--------------|
| [Project Architecture](./System/project_architecture.md) | Overall project structure, tech stack, and architectural decisions | 2025-10-08 |
| [Database Schema](./System/database_schema.md) | Complete database schema with relationships and indexes | 2025-10-08 |
| [Authentication & Authorization](./System/authentication_authorization.md) | User authentication and authorization (Devise, roles) | 2025-10-08 |
| [Carrier Matching Algorithm](./System/carrier_matching_algorithm.md) | Core business logic for matching carriers to transport requests | 2025-10-08 |

### 📝 Tasks & Feature Plans (Tasks)

**Purpose:** Product requirements and implementation plans for features (past and future).

| Document | Description | Last Updated |
|----------|-------------|--------------|
| [System Documentation Plan](./Tasks/system_documentation_plan.md) | Implementation plan for completing system documentation | 2025-10-08 |
| [Performance Optimization](./Tasks/performance_optimization.md) | Roadmap for database, algorithm, and frontend performance improvements | 2025-10-08 |
| [Customer Cargo Management Implementation](./Tasks/customer_cargo_management_implementation.md) | Implementation plan for customer cargo management feature (COMPLETED) | 2025-10-08 |

**Coming Soon:**
| `quote_system_prd.md` | Product requirements for quote & pricing system |
| `cargo_management_prd.md` | Product requirements for package/loading meter management |
| `customer_portal_prd.md` | Requirements for customer self-service portal |

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

- **Transport Request Management** 📍 *[SOP](./SOP/implementing_multi_mode_cargo_management.md)*
  - Google Maps autocomplete for addresses
  - Detailed address fields (company, street, postal code, etc.)
  - **Multi-mode cargo management:**
    - Packages mode with dynamic nested forms
    - Loading meters mode with live summary
    - Vehicle booking mode with price calculator
  - Package items with type presets and auto-fill
  - Date/time pickers with 15-min increments
  - Role-based themes (admin=blue, customer=green)

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
| 2025-10-08 | Completed system documentation: Project Architecture, Database Schema, Authentication & Authorization, Carrier Matching Algorithm; Added Database Migrations SOP; Added Performance Optimization task | Claude Code |
| 2025-10-08 | Added Multi-Mode Cargo Management SOP; Updated feature status to include cargo management details; Added Customer Cargo Management task | Claude Code |

---

**Last Review:** 2025-10-08
**Next Review Due:** 2025-11-08
