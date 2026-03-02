# iOS App — Scope & Instructions

## Ownership

The **ios/core** branch owns everything in this directory.
Do NOT modify anything in `backend/`, `pipeline/`, or `infra/`.

## Architecture

SwiftUI-first with MVVM. UIKit only for: cover image grids, custom transitions, star rating input.

```
ios/Shelf/
├── App/
│   ├── ShelfApp.swift           # App entry point
│   └── ContentView.swift        # Root navigation (tab bar)
├── Models/                      # Data models (Codable structs matching API)
├── Views/
│   ├── Auth/                    # Login, signup, onboarding
│   ├── Feed/                    # Activity feed, notifications
│   ├── Search/                  # Book search, barcode scanner
│   ├── BookDetail/              # Book detail page, ratings, reviews
│   ├── Profile/                 # User profile, shelves, stats
│   ├── Shelves/                 # Shelf list, shelf detail
│   └── Import/                  # Goodreads/StoryGraph import flow
├── ViewModels/                  # ObservableObject VMs
├── Services/
│   ├── APIClient.swift          # Network layer, auth token injection
│   ├── AuthService.swift        # Supabase Auth wrapper
│   ├── OfflineStore.swift       # SwiftData/Core Data local persistence
│   └── SyncService.swift        # Offline queue → API sync on reconnect
├── Components/                  # Reusable UI (StarRating, BookCard, CoverGrid)
├── Extensions/                  # Swift extensions
└── Resources/                   # Assets, fonts, colors
```

## Key Design Decisions

- Minimum iOS 17+ (use latest SwiftUI APIs freely)
- SwiftData for offline persistence (not Core Data, since iOS 17+)
- Supabase Swift SDK for auth
- Async/await for all network calls
- No third-party UI libraries — build custom components
- AdMob native ads styled as feed cards, every 8-10 items
- RevenueCat SDK for subscription management
- VisionKit / AVFoundation for barcode scanning
- Share extension for receiving book links from other apps

## API Base URL

```
// Development
let baseURL = "http://localhost:8000/api/v1"

// Production (Railway)
let baseURL = "https://shelf-api.up.railway.app/api/v1"
```

## API Contract

See `docs/api-contract.md` for all endpoints, request/response shapes.
Build against the contract — the backend team implements the same contract in parallel.

## Navigation Structure

```
Tab Bar:
  ├── Feed (home)
  ├── Search (+ barcode scanner)
  ├── Log (quick add — search → rate → review)
  ├── Notifications
  └── Profile
```

## Testing

XCTest for unit tests. UI tests for critical flows (login, log a book, import).
