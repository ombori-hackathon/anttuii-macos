import Foundation

/// Represents a single completion suggestion from the API
struct Completion: Codable, Identifiable {
    let id: UUID
    let text: String
    let type: String
    let description: String?
    let insertText: String
    let score: Double

    init(id: UUID = UUID(), text: String, type: String, description: String?, insertText: String, score: Double) {
        self.id = id
        self.text = text
        self.type = type
        self.description = description
        self.insertText = insertText
        self.score = score
    }

    enum CodingKeys: String, CodingKey {
        case text
        case type
        case description
        case insertText = "insert_text"
        case score
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.text = try container.decode(String.self, forKey: .text)
        self.type = try container.decode(String.self, forKey: .type)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.insertText = try container.decode(String.self, forKey: .insertText)
        self.score = try container.decode(Double.self, forKey: .score)
    }
}

/// Response from the completions API endpoint
struct CompletionResponse: Codable {
    let completions: [Completion]
    let prefixLength: Int

    enum CodingKeys: String, CodingKey {
        case completions
        case prefixLength = "prefix_length"
    }
}
