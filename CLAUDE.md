# AnttuiiClient - SwiftUI App

macOS desktop app that communicates with the FastAPI backend.

## Commands
- Build: `swift build`
- Run: `swift run AnttuiiClient` (opens GUI window)
- Test: `swift test`

## Architecture
- SwiftUI app with native macOS window
- Entry point: Sources/AnttuiiApp.swift
- Main view: Sources/ContentView.swift
- Data models: Sources/Models.swift
- Uses async/await with URLSession
- Targets macOS 14+

## API Integration
- Backend runs at http://localhost:8000
- Health check: GET /health
- Sample data: GET /items (returns list of items)

## Adding Features
1. Create new SwiftUI views in Sources/
2. Add new async functions for API calls in views or a dedicated APIClient
2. Use `URLSession.shared.data(from:)` for GET requests
3. Use `URLSession.shared.data(for:)` for POST/PUT with URLRequest
