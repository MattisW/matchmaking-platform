# Matchmaking Platform - Logistics Carrier Matching

A full-stack logistics matchmaking platform that connects shippers with carriers. Built with Next.js 15, Supabase, and TypeScript.

## 🚀 Live Demo

**GitHub Repository:** https://github.com/MattisW/matchmaking-platform

**Deployment:** Import this repository to Vercel to deploy automatically

## ✨ Features Implemented

### Phase 1 - Infrastructure ✅
- ✅ Next.js 15 with App Router and TypeScript
- ✅ Supabase database with PostgreSQL
- ✅ Row Level Security (RLS) policies
- ✅ Authentication with Supabase Auth
- ✅ Middleware for route protection
- ✅ shadcn/ui component library

### Phase 2 - Core Features ✅
- ✅ **Authentication System**
  - Login and registration pages
  - Protected dashboard routes
  - User profile management

- ✅ **Dashboard**
  - KPI metrics (requests, carriers, offers)
  - Recent activity feed
  - Sidebar navigation

- ✅ **Carrier Management**
  - List all carriers
  - Add new carriers with detailed info
  - View carrier details
  - Track fleet capabilities and service areas

- ✅ **Transport Request Management**
  - Create transport requests
  - Multi-field form with route, timing, cargo details
  - List all requests with status tracking

- ✅ **Request Detail View**
  - 5-tab interface (Overview, Route, Cargo, Offers, Communication)
  - View all request details
  - Run matching algorithm
  - View matched carriers

- ✅ **Matching Algorithm**
  - Geographic matching based on pickup/delivery countries
  - Radius-based filtering
  - Vehicle capacity validation
  - Special equipment requirements
  - Haversine distance calculation

- ✅ **Public Offer Form**
  - Carriers can submit offers via public URL
  - Form validation
  - Status tracking (new, sent, offered, accepted, rejected)

- ✅ **Offer Management**
  - Accept/reject offers
  - Auto-reject other offers when one is accepted
  - Update request status

## 🗄️ Database Schema

**4 Main Tables:**
1. **users** - Extends auth.users with role and company info
2. **carriers** - Company info, location, fleet capabilities, service area
3. **transport_requests** - Route, timing, cargo details, special requirements
4. **carrier_requests** - Junction table linking requests to carriers with offers

## 🛠️ Tech Stack

- **Framework:** Next.js 15 (App Router)
- **Language:** TypeScript
- **Database:** Supabase (PostgreSQL)
- **Authentication:** Supabase Auth
- **Styling:** Tailwind CSS
- **UI Components:** shadcn/ui
- **Forms:** React Hook Form + Zod
- **Deployment:** Vercel
- **Email:** Resend (ready to integrate)

## 📦 Environment Variables Required

```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

# Google Maps (for future geocoding)
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=your_google_maps_key

# Resend Email
RESEND_API_KEY=your_resend_key

# Stripe (optional)
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=your_stripe_key
STRIPE_SECRET_KEY=your_stripe_secret

# App URL
NEXT_PUBLIC_APP_URL=https://your-domain.vercel.app
```

## 🚀 Deployment to Vercel

### Option 1: GitHub Integration (Recommended)
1. Go to [Vercel Dashboard](https://vercel.com/new)
2. Import the GitHub repository: `https://github.com/MattisW/matchmaking-platform`
3. Add environment variables
4. Deploy!

### Option 2: Vercel CLI
```bash
npm install -g vercel
vercel login
vercel --prod
```

## 🏃 Local Development

```bash
# Install dependencies
npm install

# Set up environment variables
cp .env.example .env.local
# Fill in your values in .env.local

# Run development server
npm run dev
```

Visit http://localhost:3000

## 📋 Database Setup

The Supabase database is already set up with:
- ✅ 11 migrations applied
- ✅ All tables created
- ✅ RLS policies configured
- ✅ Indexes created
- ✅ Triggers for user creation

## 🎯 What's Working

1. **User Registration & Login** - Full authentication flow
2. **Dashboard** - Real-time KPIs and metrics
3. **Carrier CRUD** - Create, read, update carriers
4. **Request CRUD** - Create and view transport requests
5. **Matching Algorithm** - Intelligent carrier matching with multiple filters
6. **Public Offer Form** - Carriers can submit offers via unique URLs
7. **Offer Acceptance** - Dispatchers can accept/reject offers

## 🚧 Future Enhancements (Optional)

- Email notifications (Resend integration ready)
- Google Maps integration for geocoding
- Advanced analytics dashboard
- Invoice generation
- Document storage
- Real-time shipment tracking
- Multi-language support
- Payment processing with Stripe

## 📄 License

MIT

## 🤖 Built with Claude Code

This project was built using [Claude Code](https://claude.com/claude-code) - Anthropic's AI-powered coding assistant.

---

**Repository:** https://github.com/MattisW/matchmaking-platform

**Ready to deploy to Vercel!**
