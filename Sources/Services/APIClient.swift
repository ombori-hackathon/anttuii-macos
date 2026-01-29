import Foundation

/// API client for communicating with the Anttuii backend
actor APIClient {
    static let shared = APIClient()

    private let baseURL = "http://localhost:8000"
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    /// Fetch completions for the given input
    /// - Parameters:
    ///   - input: The current command line input
    ///   - cursorPosition: Position of cursor in the input
    ///   - cwd: Current working directory
    ///   - shell: Shell type (default: zsh)
    /// - Returns: CompletionResponse with suggestions
    func fetchCompletions(
        input: String,
        cursorPosition: Int,
        cwd: String,
        shell: String = "zsh"
    ) async throws -> CompletionResponse {
        guard let url = URL(string: "\(baseURL)/api/v1/completions") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "input": input,
            "cursor_position": cursorPosition,
            "cwd": cwd,
            "shell": shell
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError
        }

        return try decoder.decode(CompletionResponse.self, from: data)
    }

    /// Check if the API is healthy and reachable
    /// - Returns: true if API is healthy, false otherwise
    func checkHealth() async -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else {
            return false
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
               json["status"] == "healthy" {
                return true
            }

            return false
        } catch {
            return false
        }
    }
}

/// API errors
enum APIError: Error, LocalizedError {
    case invalidURL
    case serverError
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .serverError:
            return "Server returned an error"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}
