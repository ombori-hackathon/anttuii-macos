import SwiftUI

struct ContentView: View {
    @State private var items: [Item] = []
    @State private var isLoading = false
    @State private var apiStatus = "Checking..."
    @State private var errorMessage: String?

    private let baseURL = "http://localhost:8000"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("anttuii")
                    .font(.title.bold())
                Spacer()
                Circle()
                    .fill(apiStatus == "healthy" ? .green : .red)
                    .frame(width: 12, height: 12)
                Text(apiStatus)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.bar)

            Divider()

            // Content
            if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.secondary)
                    Text("Start API: cd services/api && uv run fastapi dev")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoading {
                ProgressView("Loading items...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ItemsTable(items: items)
            }
        }
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        // Check health
        do {
            let url = URL(string: "\(baseURL)/health")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let health = try JSONDecoder().decode(HealthResponse.self, from: data)
            apiStatus = health.status
        } catch {
            apiStatus = "offline"
            errorMessage = "API not running"
            isLoading = false
            return
        }

        // Fetch items
        do {
            let url = URL(string: "\(baseURL)/items")!
            let (data, _) = try await URLSession.shared.data(from: url)
            items = try JSONDecoder().decode([Item].self, from: data)
        } catch {
            errorMessage = "Failed to load items"
        }

        isLoading = false
    }
}
