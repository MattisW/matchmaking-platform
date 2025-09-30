# Tech Stack - Matchmaking Platform

## Core Infrastructure

### Hosting & Deployment
- **Vercel** - Next.js hosting and deployment
  - Free tier includes: Automatic deployments, serverless functions, edge network
  - Upgrade at $20/month for team features

### Database & Backend Services
- **Supabase** - PostgreSQL database + backend services
  - Includes: PostgreSQL database, Authentication, File storage, Realtime subscriptions
  - Free tier: 500MB database, 1GB storage, 2GB bandwidth
  - Upgrade at $25/month for 8GB database

### Database Client
- **Supabase JS Client** - Single library for all Supabase features
  - Handles: Database queries, auth, storage, realtime
  - Alternative considered: Prisma (more portable but adds complexity)

## Frontend Stack

### Framework & Language
- **Next.js 15** - React framework with App Router
- **TypeScript** - Type-safe JavaScript
- **App Router** - Modern Next.js routing (not Pages Router)

### Styling & UI
- **Tailwind CSS** - Utility-first CSS framework
- **shadcn/ui** - Pre-built, customizable component library
  - Built on Radix UI primitives
  - Components copied into your project (not npm dependency)
  - Fully customizable with Tailwind

## External Services

### Maps & Geolocation
- **Google Maps Platform** - Maps, geocoding, distance calculations
  - APIs needed: Maps JavaScript API, Places API, Distance Matrix API, Geocoding API
  - Free tier: $200/month credit
  - Estimated cost: $0-20/month for initial usage

### Email Service
- **Resend** - Transactional email delivery
  - Free tier: 3,000 emails/month
  - Upgrade at $20/month for 50,000 emails
  - Simple API, great developer experience

### Payment Processing (Optional)
- **Stripe** - Payment processing
  - No monthly fees
  - Transaction fees: 2.9% + $0.30 per transaction
  - Only implement if handling payments

## Development Tools

### Package Manager
- **npm** or **pnpm** (recommended for faster installs)

### Code Quality
- **ESLint** - JavaScript/TypeScript linting (included in Next.js)
- **Prettier** - Code formatting (optional but recommended)

### Version Control
- **Git** + **GitHub** - Version control and repository hosting

## Architecture Patterns

### Server-Side Logic
- **Server Actions** - For mutations and business logic (form submissions, matching algorithm)
- **Server Components** - For data fetching and rendering
- **API Routes** - For webhooks and public endpoints

### Client-Side Logic
- **Client Components** - For interactivity (forms, maps, real-time updates)
- **React Hook Form** - Form management and validation
- **Zod** - Schema validation

### Database Access
- **Row Level Security (RLS)** - Enforce permissions at database level
- **Supabase Policies** - Define who can read/write what data

## What We're NOT Using

### Explicitly Avoided
- ❌ **Prisma** - Supabase client is simpler for this use case
- ❌ **N8N or Zapier** - Building workflows directly in Next.js
- ❌ **Separate Auth Service** - Using Supabase Auth
- ❌ **Separate Storage Service** - Using Supabase Storage
- ❌ **Separate Realtime Service** - Using Supabase Realtime
- ❌ **Firebase** - Supabase provides everything we need
- ❌ **MongoDB** - PostgreSQL is better for relational data

### Defer Until Later
- ⏸️ **Workflow tools (Inngest)** - Only if workflows become complex
- ⏸️ **Error tracking (Sentry)** - After launch
- ⏸️ **Analytics** - After launch
- ⏸️ **Testing frameworks** - After core features work

## Cost Summary

### Starting Costs
```
Vercel:        $0/month (Hobby plan)
Supabase:      $0/month (Free tier)
Google Maps:   $0-20/month (within free credit)
Resend:        $0/month (Free tier)
Stripe:        $0/month (transaction fees only)
────────────────────────────
TOTAL:         $0-20/month
```

### First Upgrade (~100 users, 1000 requests/month)
```
Vercel:        $20/month (Pro plan)
Supabase:      $25/month (Pro tier)
Google Maps:   $20-50/month
Resend:        $20/month (if >3k emails)
────────────────────────────
TOTAL:         $85-115/month
```

## Key Technical Decisions

### Why Next.js 15?
- Server Actions eliminate need for separate API layer
- App Router provides better performance and DX
- Vercel deployment is seamless
- TypeScript support is excellent

### Why Supabase over Firebase?
- PostgreSQL vs NoSQL (better for relational data)
- Better developer experience
- Open source and self-hostable
- More generous free tier
- RLS policies are more powerful

### Why Tailwind + shadcn/ui?
- Fastest way to build professional UI
- Complete ownership of component code
- No runtime CSS-in-JS overhead
- Easy customization

### Why Google Maps over Mapbox?
- Better autocomplete and geocoding
- More accurate for European addresses
- $200 monthly credit covers initial usage
- Familiar to end users

### Why Resend over SendGrid/Mailgun?
- Simpler API
- Better developer experience
- More generous free tier
- Built for transactional emails

## Environment Variables Required

```bash
# Supabase
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=

# Google Maps
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=

# Resend
RESEND_API_KEY=

# Stripe (optional)
STRIPE_SECRET_KEY=
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=

# App Configuration
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

## Tech Stack Review Date
This stack should be reviewed after:
- 1,000 active users
- 10,000 transport requests
- 100,000 emails sent per month
- If any service becomes a bottleneck

At that point, consider:
- Dedicated workflow service (Inngest)
- CDN for static assets
- Error tracking (Sentry)
- Performance monitoring
- Advanced analytics
