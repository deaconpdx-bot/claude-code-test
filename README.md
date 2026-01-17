# Stone Forest App - UI Prototype

A visual prototype of the Stone Forest App customer portal and internal tools.

## Overview

This is a **front-end only** prototype built with Next.js. It uses mock JSON data to demonstrate the UI and user experience. No backend or API integration is included.

## Features

### Customer Portal
- **Dashboard**: Overview cards showing inventory alerts, active projects, and pending approvals
- **Inventory**: Table view with low-stock indicators and run rate calculations
- **Projects**: List of projects with status and ETA
- **Project Files**: File management with upload UI and approval workflow

### Internal Tools
- **Leads**: Simple CRM list for managing sales opportunities

## Tech Stack

- **Next.js 14** (App Router)
- **React 18**
- **TypeScript**
- **Tailwind CSS**

## Getting Started

### Prerequisites

- Node.js 18+ installed
- npm or yarn package manager

### Installation & Running

1. Navigate to the web app directory:
   ```bash
   cd apps/web
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Run the development server:
   ```bash
   npm run dev
   ```

4. Open your browser and navigate to:
   ```
   http://localhost:3000
   ```

5. You'll see the login page. Click **"Sign In (Demo)"** to enter the customer portal.

## Navigation

- The app starts at `/login`
- After clicking "Sign In", you'll be redirected to `/customer/dashboard`
- Use the sidebar to navigate between:
  - Customer Portal pages (Dashboard, Inventory, Projects)
  - Internal Tools (Leads)
- Switch between Customer and Internal modes using the link at the bottom of the sidebar

## Mock Data

All data is stored in JSON files in `src/mock-data/`:
- `dashboard.json` - Dashboard metrics and alerts
- `inventory.json` - Inventory items with stock levels
- `projects.json` - Project list
- `files.json` - File assets for projects
- `leads.json` - Sales leads

## Project Structure

```
apps/web/
├── src/
│   ├── app/                    # Next.js App Router pages
│   │   ├── customer/           # Customer portal pages
│   │   │   ├── dashboard/
│   │   │   ├── inventory/
│   │   │   └── projects/
│   │   ├── internal/           # Internal tools pages
│   │   │   └── leads/
│   │   ├── login/
│   │   └── layout.tsx
│   ├── components/             # Reusable UI components
│   │   ├── Sidebar.tsx
│   │   └── PageHeader.tsx
│   └── mock-data/              # JSON mock data files
├── package.json
├── tailwind.config.ts
└── tsconfig.json
```

## Features Demonstrated

### Customer Dashboard
- Summary cards with key metrics
- Alert notifications with severity levels
- Clean, modern card-based layout

### Inventory Management
- Data table with sorting and filtering potential
- Visual indicators for low stock (critical, low, healthy)
- Run rate calculations showing days remaining

### Project Management
- Project cards with status badges
- File count and approval tracking
- ETA and timeline information

### File Approval Workflow
- File listing with version information
- Upload modal (UI only)
- Approve/Request Changes buttons
- Approval history display

### Internal CRM
- Lead management table
- Status pipeline tracking
- Contact information management

## Notes

- This is a **prototype only** - no actual data persistence or backend integration
- All interactions (upload, approve, etc.) show alert messages instead of performing real actions
- The login is purely cosmetic - clicking "Sign In" navigates directly to the dashboard
- File uploads, approvals, and other actions are simulated with alert dialogs

## Building for Production

To create an optimized production build:

```bash
npm run build
npm run start
```

This will create an optimized build in the `.next` directory and start a production server
