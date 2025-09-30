# Implementation Plan - Matchmaking Platform

## Overview
This document provides a phase-by-phase implementation plan for building a logistics matchmaking platform that connects shippers with carriers. The platform will handle transport request intake, intelligent carrier matching based on geographic and capability criteria, and automated communication.

**Reference Documents:**
- Technology stack details: @TECH_STACK.md
- Original workflow: See uploaded N8N workflow JSON

---

## PROJECT STRUCTURE

```
/app
  /(auth)
    /login              # Authentication pages
    /register
  /(dashboard)          # Protected routes with sidebar layout
    /dashboard          # Main dashboard with KPIs
    /requests           # Transport requests CRUD
      /[id]             # Request detail with 5-tab view
    /carriers           # Carrier management
      /[id]             # Carrier detail
    /matches            # Active carrier-request matches
  /offer
    /[id]               # Public carrier response form
  /api
    /webhooks           # External system integrations
    /matching           # Matching algorithm trigger
/components
  /ui                   # shadcn/ui components
  /dashboard            # Dashboard-specific components
  /requests             # Request forms and displays
  /carriers             # Carrier forms and displays
  /maps                 # Google Maps integration
/lib
  /supabase
    /client.ts          # Client-side Supabase client
    /server.ts          # Server-side Supabase client
  /matching
    /algorithm.ts       # Core matching logic
    /distance.ts        # Haversine distance calculator
  /email
    /send.ts            # Email sending utilities
    /templates/         # Email templates (DE/EN)
  /utils                # Helper functions
/types
  /database.ts          # Supabase generated types
  /app.ts               # Application-specific types
```

---

## PHASE 1: SETUP & CORE INFRASTRUCTURE

### 1.1 Project Initialization

**Task:** Create new Next.js project
```bash
npx create-next-app@latest matchmaking-platform
# Select: TypeScript, Tailwind, App Router, src/ directory: NO
```

**Task:** Install core dependencies
```bash
npm install @supabase/supabase-js @supabase/ssr
npm install react-hook-form zod @hookform/resolvers
npm install @googlemaps/js-api-loader
npm install resend
```

**Task:** Install shadcn/ui
```bash
npx shadcn-ui@latest init
```

**Components to install initially:**
- Button, Card, Badge, Input, Label
- Form, Select, Checkbox, RadioGroup
- Table, Dialog, DropdownMenu
- Toast, Separator, Tabs

**Task:** Create folder structure
- Set up all folders as shown in project structure above
- Create placeholder index.ts files to commit empty directories

### 1.2 Environment Setup

**Task:** Create `.env.local` file with required variables:
```
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=
RESEND_API_KEY=
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

**Task:** Create `.env.example` (same structure, empty values)

**Task:** Add to `.gitignore`:
```
.env.local
.env*.local
```

### 1.3 Supabase Project Setup

**Task:** Create new Supabase project
1. Go to supabase.com/dashboard
2. Create new project
3. Choose region (Europe for German customers)
4. Save database password securely
5. Copy URL and anon key to `.env.local`

**Task:** Enable Authentication
1. In Supabase dashboard → Authentication → Providers
2. Enable Email provider
3. Disable email confirmations for testing (re-enable in production)
4. Note: OAuth providers can be added later

### 1.4 Database Schema

**Task:** Create tables in Supabase SQL Editor

**Table 1: users (extends auth.users)**
```sql
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('admin', 'dispatcher', 'customer')),
  company_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Trigger to create user record on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, role, company_name)
  VALUES (NEW.id, 'dispatcher', NULL);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

**Table 2: transport_requests**
```sql
CREATE TABLE public.transport_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  customer_id UUID REFERENCES public.users(id),
  status TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'matching', 'matched', 'in_transit', 'delivered', 'cancelled')),
  
  -- Route information
  start_country TEXT NOT NULL,
  start_address TEXT NOT NULL,
  start_lat DECIMAL(10, 8) NOT NULL,
  start_lng DECIMAL(11, 8) NOT NULL,
  destination_country TEXT NOT NULL,
  destination_address TEXT NOT NULL,
  destination_lat DECIMAL(10, 8) NOT NULL,
  destination_lng DECIMAL(11, 8) NOT NULL,
  distance_km INTEGER,
  
  -- Timing
  pickup_date_from TIMESTAMPTZ NOT NULL,
  pickup_date_to TIMESTAMPTZ NOT NULL,
  delivery_date_from TIMESTAMPTZ,
  delivery_date_to TIMESTAMPTZ,
  
  -- Cargo details
  vehicle_type TEXT NOT NULL CHECK (vehicle_type IN ('pkw', 'transporter', 'lkw_749', 'lkw_1199', 'lkw_bdf', 'sattelzug', 'niederzug')),
  cargo_length_cm INTEGER,
  cargo_width_cm INTEGER,
  cargo_height_cm INTEGER,
  cargo_weight_kg INTEGER,
  loading_meters DECIMAL(4, 2),
  
  -- Special requirements
  requires_liftgate BOOLEAN DEFAULT false,
  requires_pallet_jack BOOLEAN DEFAULT false,
  requires_side_loading BOOLEAN DEFAULT false,
  requires_tarp BOOLEAN DEFAULT false,
  requires_gps_tracking BOOLEAN DEFAULT false,
  driver_language TEXT CHECK (driver_language IN ('de', 'en', 'any')),
  
  -- Matching metadata
  matchmaking_status TEXT,
  matched_carrier_id UUID REFERENCES public.carriers(id)
);

CREATE INDEX idx_transport_requests_status ON public.transport_requests(status);
CREATE INDEX idx_transport_requests_customer ON public.transport_requests(customer_id);
CREATE INDEX idx_transport_requests_created ON public.transport_requests(created_at DESC);

ALTER TABLE public.transport_requests ENABLE ROW LEVEL SECURITY;
```

**Table 3: carriers**
```sql
CREATE TABLE public.carriers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Company information
  company_name TEXT NOT NULL,
  contact_email TEXT NOT NULL,
  contact_phone TEXT,
  preferred_contact_method TEXT CHECK (preferred_contact_method IN ('email', 'phone', 'whatsapp')),
  language TEXT NOT NULL DEFAULT 'de' CHECK (language IN ('de', 'en')),
  
  -- Location
  country TEXT NOT NULL,
  address TEXT NOT NULL,
  lat DECIMAL(10, 8) NOT NULL,
  lng DECIMAL(11, 8) NOT NULL,
  
  -- Service area
  pickup_radius_km INTEGER DEFAULT 50,
  ignore_radius BOOLEAN DEFAULT false,
  pickup_countries TEXT[] DEFAULT ARRAY[]::TEXT[],
  delivery_countries TEXT[] DEFAULT ARRAY[]::TEXT[],
  
  -- Fleet capabilities
  has_transporter BOOLEAN DEFAULT false,
  has_lkw BOOLEAN DEFAULT false,
  lkw_length_cm INTEGER,
  lkw_width_cm INTEGER,
  lkw_height_cm INTEGER,
  
  -- Equipment
  has_liftgate BOOLEAN DEFAULT false,
  has_pallet_jack BOOLEAN DEFAULT false,
  has_gps_tracking BOOLEAN DEFAULT false,
  
  -- Status and ratings
  blacklisted BOOLEAN DEFAULT false,
  rating_communication DECIMAL(2, 1),
  rating_punctuality DECIMAL(2, 1),
  notes TEXT
);

CREATE INDEX idx_carriers_country ON public.carriers(country);
CREATE INDEX idx_carriers_blacklisted ON public.carriers(blacklisted) WHERE NOT blacklisted;

ALTER TABLE public.carriers ENABLE ROW LEVEL SECURITY;
```

**Table 4: carrier_requests (junction table)**
```sql
CREATE TABLE public.carrier_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Relationships
  transport_request_id UUID NOT NULL REFERENCES public.transport_requests(id) ON DELETE CASCADE,
  carrier_id UUID NOT NULL REFERENCES public.carriers(id) ON DELETE CASCADE,
  
  -- Matching metadata
  distance_to_pickup_km DECIMAL(8, 2),
  distance_to_delivery_km DECIMAL(8, 2),
  in_radius BOOLEAN,
  
  -- Status and response
  status TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'sent', 'offered', 'rejected', 'expired', 'won')),
  email_sent_at TIMESTAMPTZ,
  response_date TIMESTAMPTZ,
  
  -- Offer details
  offered_price DECIMAL(10, 2),
  offered_delivery_date TIMESTAMPTZ,
  transport_type TEXT CHECK (transport_type IN ('solo', 'shared')),
  vehicle_type TEXT,
  driver_language TEXT,
  notes TEXT,
  
  UNIQUE(transport_request_id, carrier_id)
);

CREATE INDEX idx_carrier_requests_transport ON public.carrier_requests(transport_request_id);
CREATE INDEX idx_carrier_requests_carrier ON public.carrier_requests(carrier_id);
CREATE INDEX idx_carrier_requests_status ON public.carrier_requests(status);

ALTER TABLE public.carrier_requests ENABLE ROW LEVEL SECURITY;
```

### 1.5 Row Level Security Policies

**Task:** Create RLS policies for each table

**Example policy structure (apply to all tables):**
```sql
-- Admin full access
CREATE POLICY "Admins have full access"
  ON public.transport_requests
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Dispatchers can manage requests
CREATE POLICY "Dispatchers can view all requests"
  ON public.transport_requests
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role IN ('admin', 'dispatcher')
    )
  );

-- Similar policies for INSERT, UPDATE, DELETE
-- Repeat for carriers, carrier_requests tables
```

### 1.6 Supabase Client Setup

**Task:** Create Supabase client utilities

**File: `/lib/supabase/client.ts`** (client-side)
```typescript
// Create browser client for use in Client Components
```

**File: `/lib/supabase/server.ts`** (server-side)
```typescript
// Create server client for use in Server Components and Server Actions
// Use cookies for session management
```

**File: `/lib/supabase/middleware.ts`** (middleware)
```typescript
// Update session in middleware
```

### 1.7 Middleware for Route Protection

**Task:** Create `middleware.ts` in root
- Protect all `/dashboard/*` routes
- Redirect unauthenticated users to `/login`
- Allow public access to `/offer/*` routes

---

## PHASE 2: ESSENTIAL FEATURES

### 2.1 Authentication Pages

**Priority: CRITICAL - Cannot proceed without this**

**Task:** Build login page at `/app/(auth)/login/page.tsx`
- Email and password inputs
- "Sign In" button
- Link to register page
- Use Server Action for authentication
- Redirect to dashboard on success
- Show error toast on failure

**Task:** Build register page at `/app/(auth)/register/page.tsx`
- Email, password, confirm password inputs
- Company name input
- "Create Account" button
- Link to login page
- Use Server Action for registration
- Auto-login after registration

**Task:** Create auth Server Actions in `/app/actions/auth.ts`
- `signIn(email, password)`
- `signUp(email, password, companyName)`
- `signOut()`

**Testing checkpoint:**
- [ ] Can create new account
- [ ] Can log in with created account
- [ ] Redirects to dashboard after login
- [ ] Can log out
- [ ] Cannot access dashboard when logged out

### 2.2 Dashboard Layout

**Priority: HIGH - Needed for all dashboard features**

**Task:** Create dashboard layout at `/app/(dashboard)/layout.tsx`
- Sidebar with navigation links
- User menu in header (with sign out)
- Main content area
- Make sidebar responsive (collapse on mobile)

**Navigation items:**
- Dashboard (overview)
- Requests
- Carriers
- Matches

**Task:** Create dashboard home at `/app/(dashboard)/dashboard/page.tsx`
- Welcome message
- Key metrics cards:
  - Total requests (this month)
  - Active requests
  - Total carriers
  - Pending offers
- Recent activity list

**Testing checkpoint:**
- [ ] Sidebar navigation works
- [ ] Can sign out from user menu
- [ ] Metrics display correctly
- [ ] Layout is responsive

### 2.3 Carrier Management

**Priority: HIGH - Needed before matching can work**

**Task:** Build carrier list page at `/app/(dashboard)/carriers/page.tsx`
- Table showing: Company name, Country, Vehicle types, Contact, Status
- Search by company name
- Filter by country, blacklist status
- "Add Carrier" button
- Pagination (20 per page)
- Click row to view details

**Task:** Build add carrier page at `/app/(dashboard)/carriers/new/page.tsx`
- Multi-section form:
  - Company info (name, email, phone, language)
  - Location (address with Google autocomplete, country)
  - Service area (pickup radius, countries served)
  - Fleet capabilities (checkboxes for transporter/LKW, dimensions)
  - Equipment (checkboxes for liftgate, pallet jack, etc.)
- Validate all fields
- Use Server Action to save
- Redirect to carrier list on success

**Task:** Build edit carrier page at `/app/(dashboard)/carriers/[id]/edit/page.tsx`
- Same form as add carrier
- Pre-populate with existing data
- Update instead of create

**Task:** Build carrier detail page at `/app/(dashboard)/carriers/[id]/page.tsx`
- Display all carrier information
- Show performance metrics (if available)
- List of recent requests sent to this carrier
- Edit and delete buttons

**Task:** Create carrier Server Actions in `/app/actions/carriers.ts`
- `createCarrier(data)`
- `updateCarrier(id, data)`
- `deleteCarrier(id)`
- `getCarriers(filters)`
- `getCarrier(id)`

**Testing checkpoint:**
- [ ] Can add new carrier with all fields
- [ ] Google autocomplete works for address
- [ ] Can edit existing carrier
- [ ] Can view carrier details
- [ ] Can delete carrier
- [ ] Search and filters work

### 2.4 Transport Request Creation

**Priority: HIGH - Core feature**

**Task:** Build request list page at `/app/(dashboard)/requests/page.tsx`
- Table showing: Request #, Customer, Route, Status, Date
- Search by route or customer
- Filter by status
- "New Request" button
- Pagination
- Click row to view details

**Task:** Build new request page at `/app/(dashboard)/requests/new/page.tsx`

**Multi-step form (4 steps):**

**Step 1: Route Information**
- Start address (Google Places Autocomplete)
- Destination address (Google Places Autocomplete)
- Show map preview with route
- Auto-calculate distance
- "Next" button

**Step 2: Timing**
- Pickup date range (from/to datetime pickers)
- Delivery date range (from/to datetime pickers)
- "Back" and "Next" buttons

**Step 3: Cargo Details**
- Vehicle type selector (radio buttons)
- Dimensions inputs (length, width, height in cm)
- Weight input (kg)
- Loading meters (calculated or manual)
- Special requirements (checkboxes):
  - Requires liftgate
  - Requires pallet jack
  - Requires side loading
  - Requires tarp
  - GPS tracking required
- Driver language preference
- "Back" and "Next" buttons

**Step 4: Review & Submit**
- Summary of all information in sections
- Map showing route
- "Back" and "Submit" buttons
- On submit: create request with status 'new'

**Task:** Create request Server Actions in `/app/actions/requests.ts`
- `createRequest(data)`
- `updateRequest(id, data)`
- `getRequests(filters)`
- `getRequest(id)`
- `cancelRequest(id)`

**Testing checkpoint:**
- [ ] Can complete all 4 steps
- [ ] Google autocomplete works
- [ ] Map displays route correctly
- [ ] Distance is calculated
- [ ] Form validation catches errors
- [ ] Request is created in database
- [ ] Can navigate back/forward through steps

### 2.5 Request Detail View

**Priority: HIGH - Needed to view and manage requests**

**Task:** Build request detail page at `/app/(dashboard)/requests/[id]/page.tsx`

**Five-tab interface:**

**Tab 1: Overview**
- Status badge
- Request number and date
- Customer information
- Quick stats (matched carriers, offers received)
- Action buttons:
  - "Run Matching" (if status is 'new')
  - "Cancel Request"
- Timeline of status changes

**Tab 2: Route & Timing**
- Full-screen map showing route
- Start location details (address, coordinates)
- Destination location details
- Pickup window
- Delivery window
- Distance and estimated duration

**Tab 3: Cargo**
- Vehicle type
- Visual representation of dimensions
- Weight
- Loading meters
- Special requirements list
- Driver language requirement

**Tab 4: Offers**
- Table of carrier_requests for this transport_request
- Columns: Carrier, Distance, Offered Price, Status, Response Time
- Filter by status
- Sort by price, distance
- Actions per offer:
  - View carrier details
  - Accept offer (if status is 'offered')
  - Reject offer
- If no offers: "Run matching to find carriers"

**Tab 5: Communication**
- Timeline of emails sent
- Manual notes textarea
- "Send Update Email" button

**Testing checkpoint:**
- [ ] All tabs display correct information
- [ ] Map renders correctly
- [ ] Can switch between tabs
- [ ] Action buttons work
- [ ] Timeline shows events

### 2.6 Matching Algorithm

**Priority: CRITICAL - Core business logic**

**Task:** Create haversine distance function in `/lib/matching/distance.ts`
```typescript
/**
 * Calculate distance between two coordinates using Haversine formula
 * Returns distance in kilometers
 */
export function calculateDistance(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number
): number
```

**Task:** Create matching algorithm in `/lib/matching/algorithm.ts`

**Function: `matchCarriersToRequest(requestId: string)`**

**Logic flow:**
1. Fetch request details from database
2. Fetch all non-blacklisted carriers
3. **Filter 1: Check vehicle availability**
   - If request needs transporter: carrier.has_transporter must be true
   - If request needs LKW: carrier.has_lkw must be true
4. **Filter 2: Geographic coverage**
   - carrier.pickup_countries must include request.start_country
   - carrier.delivery_countries must include request.destination_country
5. **Filter 3: Radius check** (skip if carrier.ignore_radius)
   - Calculate distance from carrier.lat/lng to request.start_lat/lng
   - Keep only if distance <= carrier.pickup_radius_km
6. **Filter 4: Vehicle capacity** (if LKW required)
   - carrier.lkw_length_cm >= request.cargo_length_cm
   - carrier.lkw_width_cm >= request.cargo_width_cm
   - carrier.lkw_height_cm >= request.cargo_height_cm
7. **Filter 5: Special equipment**
   - If request.requires_liftgate: carrier.has_liftgate must be true
   - If request.requires_pallet_jack: carrier.has_pallet_jack must be true
8. **For each matched carrier:**
   - Calculate distance_to_pickup_km
   - Calculate distance_to_delivery_km
   - Create carrier_request record with:
     - Status: 'new'
     - All calculated distances
     - in_radius: true/false
9. **Update request:**
   - Set matchmaking_status to 'completed'
   - Set status to 'matching' → 'matched' if carriers found
10. **Return:** Count of matched carriers

**Task:** Create Server Action in `/app/actions/matching.ts`
- `runMatching(requestId)` - wrapper around algorithm
- Update request status
- Trigger email sending (next step)
- Return success/error message

**Testing checkpoint:**
- [ ] Matching finds appropriate carriers
- [ ] Distance calculations are accurate
- [ ] All filters work correctly
- [ ] Creates carrier_request records
- [ ] Updates request status
- [ ] Returns correct count

### 2.7 Email System

**Priority: HIGH - Needed for carrier communication**

**Task:** Set up Resend API key in environment variables

**Task:** Create email templates in `/lib/email/templates/`

**Template 1: carrier-invitation-de.ts**
- Subject: "Neue Transportanfrage - [Route]"
- Body with request details
- Link to offer form: `${APP_URL}/offer/${carrierRequestId}`
- Variables: carrier name, route, dates, cargo details

**Template 2: carrier-invitation-en.ts**
- English version of template 1

**Template 3: offer-accepted.ts**
- Subject: "Ihr Angebot wurde akzeptiert"
- Body confirming they won the request
- Next steps

**Template 4: request-cancelled.ts**
- Subject: "Anfrage storniert"
- Body explaining request was cancelled
- Thank you message

**Task:** Create email sending utility in `/lib/email/send.ts`
```typescript
/**
 * Send email using Resend API
 * Logs sent emails to database (optional: create emails table)
 */
export async function sendEmail({
  to: string,
  subject: string,
  html: string,
  template: string,
  metadata: Record<string, any>
})
```

**Task:** Create email Server Actions in `/app/actions/emails.ts`
- `sendCarrierInvitations(requestId)` - send to all new carrier_requests
- `sendOfferAccepted(carrierRequestId)`
- `sendRequestCancelled(requestId)` - send to all pending carrier_requests

**Task:** Integrate email sending into matching workflow
- After matching completes, automatically send invitations
- Update carrier_request.email_sent_at timestamp

**Testing checkpoint:**
- [ ] Emails are sent successfully
- [ ] Templates render correctly
- [ ] Links work in emails
- [ ] German/English selection works
- [ ] Email_sent_at is updated

### 2.8 Carrier Offer Form

**Priority: HIGH - Allows carriers to respond**

**Task:** Build public offer form at `/app/offer/[id]/page.tsx`

**This page is PUBLIC (no auth required)**

**Logic:**
1. Fetch carrier_request by ID
2. Fetch related transport_request
3. Check transport_request.status:
   - If 'cancelled': Show "Request no longer available" message
   - If 'matched' and this carrier didn't win: Show "Request filled" message
   - Otherwise: Show form

**Form fields:**
- Offered price (EUR)
- Estimated delivery date
- Transport type: Solo / Shared (radio)
- Vehicle type confirmation (dropdown)
- Driver language (dropdown)
- Notes (optional textarea)
- "Submit Offer" button

**On submit:**
- Validate all required fields
- Update carrier_request record:
  - Set status to 'offered'
  - Save all form data
  - Set response_date to now
- Send notification email to dispatcher
- Show success message
- Redirect to thank you page

**Task:** Create Server Action in `/app/actions/offers.ts`
- `submitOffer(carrierRequestId, data)`
- Validate carrier_request exists and is still valid
- Update record
- Send notification email
- Return success/error

**Testing checkpoint:**
- [ ] Form loads for valid carrier_request
- [ ] Shows correct message for cancelled requests
- [ ] Validation works
- [ ] Can submit offer
- [ ] Dispatcher receives notification email
- [ ] Success message displays

### 2.9 Offer Management

**Priority: MEDIUM - Needed to close the loop**

**Task:** Add offer actions to request detail page (Tab 4)

**For each offer with status 'offered':**
- "Accept" button
- "Reject" button

**Task:** Create Server Actions in `/app/actions/offers.ts`
- `acceptOffer(carrierRequestId)`
  - Set this carrier_request.status to 'won'
  - Set all other carrier_requests for same transport_request to 'rejected'
  - Update transport_request.status to 'matched'
  - Set transport_request.matched_carrier_id
  - Send acceptance email to winning carrier
  - Send rejection emails to other carriers
- `rejectOffer(carrierRequestId)`
  - Set carrier_request.status to 'rejected'
  - Send rejection email to carrier

**Testing checkpoint:**
- [ ] Can accept an offer
- [ ] Other offers are automatically rejected
- [ ] Request status updates to 'matched'
- [ ] Emails are sent to all parties
- [ ] Can manually reject an offer

---

## PHASE 3: TESTING & REFINEMENT

### 3.1 End-to-End Testing

**Test Scenario 1: Complete Request Lifecycle**
1. Create new carrier with Germany pickup, France delivery
2. Create transport request from Germany to France
3. Run matching
4. Verify carrier receives email
5. Submit offer via public form
6. Accept offer in dashboard
7. Verify all status updates

**Test Scenario 2: Geographic Filtering**
1. Create carrier with Germany-only service area
2. Create request from France to Spain
3. Run matching
4. Verify carrier is NOT matched

**Test Scenario 3: Radius Filtering**
1. Create carrier in Munich with 50km radius
2. Create request in Berlin (>500km away)
3. Run matching
4. Verify carrier is NOT matched

**Test Scenario 4: Capacity Filtering**
1. Create carrier with LKW max dimensions: 400cm x 200cm x 200cm
2. Create request requiring 500cm length
3. Run matching
4. Verify carrier is NOT matched

**Test Scenario 5: Multiple Offers**
1. Create 3 carriers matching same request
2. Run matching
3. Verify all 3 receive emails
4. Submit offers from 2 carriers
5. Accept one offer
6. Verify other is rejected

### 3.2 Data Validation

**Task:** Add Zod schemas for all forms
- Request creation form
- Carrier creation form
- Offer submission form

**Task:** Add validation in Server Actions
- Validate all inputs before database writes
- Return user-friendly error messages
- Prevent duplicate submissions

**Task:** Add database constraints
- NOT NULL on required fields
- CHECK constraints on enums
- UNIQUE constraints where needed
- Foreign key constraints

### 3.3 Error Handling

**Task:** Implement try-catch in all Server Actions
- Catch and log errors
- Return user-friendly error messages
- Don't expose internal errors to users

**Task:** Add toast notifications
- Success messages for completed actions
- Error messages for failed actions
- Warning messages for important info

**Task:** Add loading states
- Show spinners during data fetching
- Disable buttons during submission
- Skeleton loaders for tables and cards

**Task:** Add error boundaries
- Catch React errors
- Show fallback UI
- Provide way to retry/go back

### 3.4 Performance Optimization

**Task:** Add database indexes (if not already done)
```sql
CREATE INDEX idx_requests_status ON transport_requests(status);
CREATE INDEX idx_requests_created ON transport_requests(created_at DESC);
CREATE INDEX idx_carrier_requests_transport ON carrier_requests(transport_request_id);
CREATE INDEX idx_carriers_location ON carriers(lat, lng);
```

**Task:** Implement pagination
- Use Supabase range queries
- Add page size selector
- Show total count

**Task:** Add caching for static data
- Cache carrier list on client
- Use React Server Components for automatic caching
- Consider Vercel's data cache

**Task:** Optimize Google Maps loading
- Lazy load map components
- Use static maps for list views
- Cache geocoding results in database

### 3.5 Security Audit

**Checklist:**
- [ ] All database queries respect RLS policies
- [ ] Service role key is only used server-side
- [ ] Environment variables are not exposed to client
- [ ] User inputs are validated and sanitized
- [ ] API routes verify authentication
- [ ] Rate limiting on email sending
- [ ] CSRF protection (Next.js handles this)
- [ ] XSS protection (React handles this)
- [ ] SQL injection protection (Supabase client handles this)

### 3.6 User Experience Polish

**Task:** Add empty states
- Empty carrier list: "Add your first carrier"
- Empty request list: "Create your first transport request"
- No offers: "No offers yet. Wait for carriers to respond."

**Task:** Add confirmation dialogs
- Before deleting carrier
- Before cancelling request
- Before rejecting offer

**Task:** Add helpful tooltips
- Explain loading meters calculation
- Explain radius setting
- Explain special requirements

**Task:** Improve mobile experience
- Test all pages on mobile
- Ensure forms are usable
- Make tables responsive

### 3.7 Documentation

**Task:** Create README.md
- Project overview
- Setup instructions
- Environment variables explanation
- Development commands

**Task:** Document key business logic
- Add comments to matching algorithm
- Explain distance calculations
- Document status flow

---

## DEPLOYMENT CHECKLIST

### Before First Deploy

**Environment:**
- [ ] Create production Supabase project
- [ ] Set up production environment variables in Vercel
- [ ] Configure custom domain (if applicable)

**Database:**
- [ ] Run all SQL migrations on production database
- [ ] Create RLS policies on production
- [ ] Test database connection from Vercel

**APIs:**
- [ ] Restrict Google Maps API key to production domain
- [ ] Set up Resend production API key
- [ ] Configure Stripe webhook endpoints (if using)

**Security:**
- [ ] Enable email confirmation in Supabase Auth (production only)
- [ ] Set up rate limiting for public endpoints
- [ ] Review all RLS policies
- [ ] Test that service role key is server-only

**Testing:**
- [ ] Run through all test scenarios on production
- [ ] Test email delivery
- [ ] Test form submissions
- [ ] Verify maps load correctly

### Ongoing Maintenance

**Monitoring:**
- Set up Vercel analytics (free)
- Monitor Supabase database size
- Track Google Maps API usage
- Monitor Resend email quota

**Backups:**
- Supabase Pro includes daily backups
- Consider exporting critical data weekly

**Updates:**
- Keep Next.js and dependencies updated
- Review Supabase changelog for breaking changes
- Test updates on staging before production

---

## OPTIONAL ENHANCEMENTS (Post-MVP)

### Nice to Have Features
- Carrier ratings and reviews
- Customer portal for self-service
- Real-time shipment tracking
- Invoice generation
- Document storage (POD, CMR)
- Multi-language support (more languages)
- Advanced analytics dashboard
- Export to Excel/PDF
- Automated report generation
- Integration with accounting software

### Technical Improvements
- Add automated testing (Playwright)
- Set up error tracking (Sentry)
- Implement proper logging
- Add performance monitoring
- Set up CI/CD pipeline
- Add staging environment
- Implement feature flags

---

## COMMON PITFALLS TO AVOID

1. **Don't skip RLS policies** - Test that users can only see their data
2. **Don't expose service role key** - Only use in Server Actions/API routes
3. **Don't forget loading states** - Users need feedback during async operations
4. **Don't ignore mobile** - Test on actual mobile devices
5. **Don't over-optimize early** - Get it working first, then optimize
6. **Don't forget error handling** - Every Server Action should handle errors
7. **Don't hardcode** - Use environment variables for all configs
8. **Don't skip validation** - Validate on both client and server
9. **Don't trust client data** - Always validate in Server Actions
10. **Don't forget to test email** - Use real email addresses in testing

---

## SUCCESS METRICS

**Phase 1 Complete When:**
- Can create Supabase project
- Can connect Next.js to Supabase
- Database schema is created
- Development environment is set up

**Phase 2 Complete When:**
- Can register and log in
- Can create carriers and requests
- Matching algorithm works correctly
- Carriers receive invitation emails
- Carriers can submit offers
- Dispatchers can accept offers

**Phase 3 Complete When:**
- All test scenarios pass
- No critical bugs
- Performance is acceptable
- Security checklist is complete
- Ready to deploy to production

---

## GETTING STARTED

To begin implementation:

1. Copy this file and @TECH_STACK.md to your project
2. Start with Phase 1, Section 1.1
3. Complete each task in order
4. Test thoroughly before moving to next section
5. Use Claude Code to implement each task
6. Ask for help when stuck, but try to solve problems first

**Example prompt for Claude Code:**
```
I'm ready to start Phase 1, Section 1.1 - Project Initialization.
@PLANNING.md @TECH_STACK.md

Please:
1. Create the Next.js project with the correct configuration
2. Install all core dependencies
3. Set up the folder structure
4. Initialize shadcn/ui and install the initial components

Proceed with these tasks and let me know when Phase 1.1 is complete.
```
