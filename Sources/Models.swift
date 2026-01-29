import Foundation

struct Item: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String
    let price: Double
}

struct HealthResponse: Codable {
    let status: String
}
