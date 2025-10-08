# Authentication & Authorization

**Last Updated:** 2025-10-08
**Related Docs:** [Project Architecture](./project_architecture.md), [Database Schema](./database_schema.md)

---

## Overview

The platform uses **Devise** for authentication with a **role-based authorization** system. There are three user roles (admin, dispatcher, customer) and a separate carrier access pattern (token-based, no authentication).

**Key Principles:**
- ✅ Users authenticate via Devise (email/password)
- ✅ Roles determine layout and access level
- ✅ Carriers access via unique tokens (no authentication)
- ✅ Layout auto-switches based on role
- ✅ Before-action filters enforce authorization

---

## Devise Configuration

### Modules Enabled

**Location:** `config/initializers/devise.rb`

```ruby
Devise.setup do |config|
  # Authentication modules
  config.database_authenticatable  # Password login
  config.registerable              # Sign up
  config.recoverable               # Password reset
  config.rememberable              # "Remember me" checkbox
  config.validatable               # Email/password validation

  # NOT enabled (for now):
  # config.confirmable    # Email confirmation
  # config.lockable       # Account locking
  # config.timeoutable    # Session timeout
  # config.trackable      # Sign-in tracking
end
```

### User Model

**Location:** `app/models/user.rb`

```ruby
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Validations
  validates :role, inclusion: { in: %w[admin dispatcher customer] }
  validates :company_name, presence: true
  validates :locale, inclusion: { in: %w[de en] }, allow_nil: false

  # Role helpers
  def admin?
    role == "admin"
  end

  def dispatcher?
    role == "dispatcher"
  end

  def customer?
    role == "customer"
  end

  def admin_or_dispatcher?
    admin? || dispatcher?
  end
end
```

### Database Fields

**Authentication (Devise):**
- `email` - Login identifier (unique)
- `encrypted_password` - Bcrypt hash
- `reset_password_token` - Password reset token (unique)
- `reset_password_sent_at` - Reset token timestamp
- `remember_created_at` - Remember me timestamp

**Custom:**
- `role` - User role (default: 'dispatcher')
- `company_name` - Organization name
- `locale` - Preferred language (de, en)
- `theme_mode`, `accent_color`, etc. - UI preferences

---

## Role System

### Three Roles

#### 1. Admin (`role='admin'`)

**Access Level:** Full platform access

**Capabilities:**
- ✅ Manage carriers (CRUD)
- ✅ Manage all transport requests (any customer)
- ✅ Run matching algorithm
- ✅ Accept/reject offers on behalf of customers
- ✅ Configure pricing rules
- ✅ View all system activity
- ✅ Access admin namespace

**Layout:** `layouts/admin.html.erb` (gray sidebar)

#### 2. Dispatcher (`role='dispatcher'`)

**Access Level:** Same as admin (legacy naming)

**Note:** Originally intended to be separate, but currently has identical permissions to admin. Can be differentiated in the future if needed.

**Layout:** `layouts/admin.html.erb`

#### 3. Customer (`role='customer'`)

**Access Level:** Own data only

**Capabilities:**
- ✅ Create transport requests
- ✅ View own requests only
- ✅ Review quotes
- ✅ Accept/decline quotes (triggers matching)
- ✅ View carrier offers
- ✅ Accept/reject carrier offers
- ❌ Cannot access admin features
- ❌ Cannot see other customers' data

**Layout:** `layouts/customer.html.erb` (blue sidebar)

### Role Helpers

**In Models:**
```ruby
user.admin?              # => true if role == 'admin'
user.dispatcher?         # => true if role == 'dispatcher'
user.customer?           # => true if role == 'customer'
user.admin_or_dispatcher? # => true if admin OR dispatcher
```

**In Views:**
```erb
<% if current_user.admin? %>
  <div class="admin-only-content">...</div>
<% end %>

<% if current_user.customer? %>
  <%= link_to "My Requests", customer_transport_requests_path %>
<% end %>
```

---

## Authorization System

### Controller Filters

**Location:** `app/controllers/application_controller.rb`

```ruby
class ApplicationController < ActionController::Base
  # Authorization helpers
  def ensure_admin!
    unless current_user&.admin_or_dispatcher?
      redirect_to root_path, alert: "Access denied. Admin privileges required."
    end
  end

  def ensure_customer!
    unless current_user&.customer?
      redirect_to root_path, alert: "Access denied. This area is for customers only."
    end
  end
end
```

### Admin Controllers

**Pattern:**
```ruby
module Admin
  class CarriersController < ApplicationController
    before_action :authenticate_user!  # Devise
    before_action :ensure_admin!       # Role check
    layout "admin"

    def index
      @carriers = Carrier.all  # Can see all
    end
  end
end
```

**Authorization Flow:**
1. `authenticate_user!` - Ensures user is logged in
2. `ensure_admin!` - Ensures user has admin/dispatcher role
3. If fails: Redirect to root with alert

### Customer Controllers

**Pattern:**
```ruby
module Customer
  class TransportRequestsController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_customer!
    layout "customer"

    def index
      # Scoped to current user
      @requests = current_user.transport_requests.order(created_at: :desc)
    end
  end
end
```

**Data Scoping:**
```ruby
# Admin - sees all
TransportRequest.all

# Customer - sees only own
current_user.transport_requests
```

### Public Controllers (No Auth)

**Example:** `OffersController` (carrier offer submission)

```ruby
class OffersController < ApplicationController
  skip_before_action :authenticate_user!  # No login required
  layout "application"

  def show
    @carrier_request = CarrierRequest.find_by(token: params[:id])
    # Token provides access control
  end
end
```

**Access Control:**
- No `authenticate_user!` filter
- Token-based access via URL
- Public layout
- No session required

---

## Layout Routing

### Automatic Layout Selection

**Location:** `app/controllers/application_controller.rb`

```ruby
layout :layout_by_resource

private

def layout_by_resource
  if devise_controller?
    "devise"                      # Login/signup pages
  elsif current_user&.customer?
    "customer"                    # Customer portal
  elsif current_user&.admin_or_dispatcher?
    "admin"                       # Admin panel
  else
    "application"                 # Public pages
  end
end
```

### Four Layouts

#### 1. `layouts/devise.html.erb`
- **Used For:** Login, signup, password reset
- **Style:** Minimal, centered form
- **No Sidebar:** Clean authentication UI

#### 2. `layouts/admin.html.erb`
- **Used For:** Admin/dispatcher users
- **Sidebar:** Gray (#1F2937)
- **Navigation:** Carriers, Requests, Offers, Pricing Rules
- **Top Bar:** Page title, action buttons
- **Footer:** User email, language switcher, logout

#### 3. `layouts/customer.html.erb`
- **Used For:** Customer users
- **Sidebar:** Blue (#1E3A8A)
- **Navigation:** Dashboard, My Requests
- **Top Bar:** Page title, "New Request" button
- **Footer:** User email, logout

#### 4. `layouts/application.html.erb`
- **Used For:** Public pages (offers, health check)
- **Style:** Minimal
- **No Sidebar:** Simple content area

### Layout Auto-Switch Example

```ruby
# User logs in as admin
current_user.admin? # => true
# → Routed to admin layout

# User logs in as customer
current_user.customer? # => true
# → Routed to customer layout

# User visits public offer link
# → Routed to application layout (no auth)
```

---

## Root Path Routing

### Role-Based Root

**Location:** `config/routes.rb`

```ruby
# Admin/Dispatcher root
authenticated :user, ->(user) { user.admin_or_dispatcher? } do
  root to: "dashboard#index", as: :admin_root
end

# Customer root
authenticated :user, ->(user) { user.customer? } do
  root to: "customer/dashboard#show", as: :customer_root
end

# Fallback for unauthenticated
root "dashboard#index"
```

**Behavior:**
- Admin logs in → Redirected to `/` (admin dashboard)
- Customer logs in → Redirected to `/` (customer dashboard)
- Not logged in → Public page (or login redirect)

**Named Routes:**
```ruby
admin_root_path      # => /
customer_root_path   # => /
root_path            # => / (context-dependent)
```

---

## Carrier Access Pattern (No Authentication)

### Why No Authentication?

**Design Decision:** Carriers are NOT users

**Rationale:**
1. **Simplicity:** No onboarding, no passwords
2. **B2B Workflow:** Email-based is natural
3. **Minimal Features:** Only submit offers
4. **Security:** Tokens provide access control
5. **Scale:** No account management overhead

### Token-Based Access

**How It Works:**

1. **Matching Algorithm Creates CarrierRequest:**
   ```ruby
   CarrierRequest.create!(
     transport_request: @request,
     carrier: @carrier,
     token: SecureRandom.urlsafe_base64(32),  # Unique token
     status: 'new'
   )
   ```

2. **Email Sent with Token Link:**
   ```ruby
   CarrierMailer.invitation(@carrier_request).deliver_later
   # Email contains: https://example.com/offers/{token}/submit
   ```

3. **Carrier Clicks Link (No Login):**
   ```ruby
   # OffersController
   def show
     @carrier_request = CarrierRequest.find_by(token: params[:id])
     # If token invalid: 404
     # If valid: Show offer form
   end
   ```

4. **Carrier Submits Offer:**
   ```ruby
   def submit_offer
     @carrier_request = CarrierRequest.find_by(token: params[:id])
     @carrier_request.update!(
       offered_price: params[:price],
       status: 'offered'
     )
     # Show confirmation page
   end
   ```

**Security Considerations:**
- Tokens are 32-character URL-safe base64 (cryptographically random)
- One-time use pattern (status changes prevent re-submission)
- No password to compromise
- No session to hijack
- Email provides identity verification

**Limitations:**
- Token link in email could be forwarded
- No audit trail of who submitted offer
- Future: Add IP logging, submission timestamps

---

## Session Management

### Devise Sessions

**Login:**
```ruby
# POST /users/sign_in
# Params: { user: { email:, password:, remember_me: } }

# Success: Set session, redirect to root (role-based)
# Failure: Re-render login with errors
```

**Logout:**
```ruby
# DELETE /users/sign_out
# Clears session, redirects to login
```

**Remember Me:**
- Checkbox on login form
- Sets persistent cookie (default: 2 weeks)
- Managed by Devise

### Session Security

**CSRF Protection:**
- Enabled by default (Rails)
- Token in form fields
- Verified on POST/PUT/DELETE

**Secure Cookies:**
```ruby
# config/initializers/session_store.rb
Rails.application.config.session_store :cookie_store,
  key: '_matchmaking_session',
  secure: Rails.env.production?,  # HTTPS only in prod
  httponly: true,                 # No JS access
  same_site: :lax                 # CSRF protection
```

---

## Permitted Parameters

### Devise Registration

**Location:** `app/controllers/application_controller.rb`

```ruby
before_action :configure_permitted_parameters, if: :devise_controller?

private

def configure_permitted_parameters
  # Sign up (allow role & company_name)
  devise_parameter_sanitizer.permit(:sign_up, keys: [:company_name, :role])

  # Account update (allow company_name only)
  devise_parameter_sanitizer.permit(:account_update, keys: [:company_name])
end
```

**Sign Up Form:**
```erb
<%= form_for(resource, as: :user, url: registration_path(resource_name)) do |f| %>
  <%= f.email_field :email %>
  <%= f.password_field :password %>
  <%= f.text_field :company_name %>
  <%= f.select :role, [['Admin', 'admin'], ['Customer', 'customer']] %>
<% end %>
```

**Security Note:**
- ⚠️ Currently allows self-registration as admin
- **Production:** Should restrict admin creation to invite-only

---

## Localization & Sessions

### User Locale

**Storage:** `users.locale` column (de, en)

**Setting:** `ApplicationController#set_locale`

```ruby
before_action :set_locale

private

def set_locale
  I18n.locale = current_user&.locale ||
                extract_locale_from_accept_language_header ||
                I18n.default_locale
end

def extract_locale_from_accept_language_header
  request.env['HTTP_ACCEPT_LANGUAGE']&.scan(/^[a-z]{2}/)&.first&.to_sym
end
```

**Priority:**
1. User's saved locale (if logged in)
2. Browser Accept-Language header
3. Default locale (`:de`)

### Locale Switching

**Route:** `POST /switch_locale`

**Controller:**
```ruby
def switch_locale
  if current_user && params[:locale].in?(I18n.available_locales.map(&:to_s))
    current_user.update(locale: params[:locale])
    redirect_back(fallback_location: root_path, notice: t('locale.switched'))
  else
    redirect_back(fallback_location: root_path, alert: t('flash.error'))
  end
end
```

**View:**
```erb
<%= form_with url: switch_locale_path, method: :post do |f| %>
  <%= f.select :locale,
      [['🇩🇪 Deutsch', 'de'], ['🇬🇧 English', 'en']],
      {},
      { onchange: 'this.form.submit()' } %>
<% end %>
```

---

## Authorization Patterns

### Controller-Level

```ruby
# Admin only
class Admin::CarriersController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!

  # All actions require admin role
end

# Customer only
class Customer::TransportRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_customer!

  # All actions require customer role
end

# Mixed (public + authenticated)
class OffersController < ApplicationController
  skip_before_action :authenticate_user!  # Public access

  # No role check, token provides access
end
```

### Data-Level

```ruby
# Admin: See all data
@requests = TransportRequest.all

# Customer: Scoped to user
@requests = current_user.transport_requests

# Filter out blacklisted
@carriers = Carrier.where(blacklisted: false)
```

### View-Level

```erb
<%# Show only to admins %>
<% if current_user.admin_or_dispatcher? %>
  <%= link_to "Admin Panel", admin_root_path %>
<% end %>

<%# Show only to customers %>
<% if current_user.customer? %>
  <%= link_to "My Requests", customer_transport_requests_path %>
<% end %>

<%# Show to authenticated users %>
<% if user_signed_in? %>
  <%= link_to "Logout", destroy_user_session_path, method: :delete %>
<% end %>
```

---

## Security Considerations

### Implemented Protections

✅ **Password Security:**
- Bcrypt encryption (Devise default)
- Minimum length: 6 characters (Devise default)
- Password reset via email

✅ **Session Security:**
- HttpOnly cookies (no JS access)
- Secure cookies in production (HTTPS only)
- CSRF protection (Rails default)

✅ **Authorization:**
- Before-action filters on all protected controllers
- Data scoping by user (customers see only own data)
- Role validation in model

✅ **Token Security:**
- Cryptographically random tokens (SecureRandom)
- 32-character URL-safe base64
- Unique per carrier request

### Missing Protections (Future Enhancements)

⚠️ **Admin Registration:**
- Currently: Self-registration as admin is possible
- **Fix:** Restrict to invite-only or seed data

⚠️ **Rate Limiting:**
- No login attempt limits
- **Fix:** Add rack-attack gem

⚠️ **Email Confirmation:**
- Devise confirmable not enabled
- **Fix:** Enable for production

⚠️ **Account Lockout:**
- No failed login lockout
- **Fix:** Enable Devise lockable

⚠️ **Two-Factor Auth:**
- Not implemented
- **Fix:** Add for admin accounts

---

## Testing Authorization

### Manual Testing Checklist

**Admin Access:**
- [ ] Admin can access `/admin/carriers`
- [ ] Admin can see all transport requests
- [ ] Admin can configure pricing rules
- [ ] Admin redirected to admin dashboard on login

**Customer Access:**
- [ ] Customer can access `/customer/transport_requests`
- [ ] Customer sees only own requests
- [ ] Customer cannot access `/admin/*`
- [ ] Customer redirected to customer dashboard on login

**Cross-Role:**
- [ ] Customer visiting `/admin/carriers` → Redirected with alert
- [ ] Admin visiting `/customer/transport_requests` → Redirected with alert
- [ ] Unauthenticated visiting protected route → Redirected to login

**Carrier Access:**
- [ ] Valid token URL shows offer form
- [ ] Invalid token URL shows 404
- [ ] Submitted offer updates carrier_request
- [ ] No authentication required

### Automated Tests (Future)

```ruby
# spec/requests/admin/carriers_spec.rb
describe "Admin::CarriersController" do
  context "as admin" do
    it "allows access" do
      sign_in create(:user, role: 'admin')
      get admin_carriers_path
      expect(response).to be_successful
    end
  end

  context "as customer" do
    it "denies access" do
      sign_in create(:user, role: 'customer')
      get admin_carriers_path
      expect(response).to redirect_to(root_path)
    end
  end
end
```

---

## Related Documentation

- **[Project Architecture](./project_architecture.md)** - System overview
- **[Database Schema](./database_schema.md)** - User table structure
- **[.agent README](../README.md)** - Documentation index

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2025-10-05 | Devise for authentication | Standard Rails solution, battle-tested |
| 2025-10-05 | String-based roles | Simple, extensible, no gem needed |
| 2025-10-05 | No carrier authentication | Email workflow sufficient for B2B |
| 2025-10-06 | Layout auto-switching | Better UX than manual layout selection |

---

**Last Review:** 2025-10-08
**Next Review Due:** 2025-11-08
