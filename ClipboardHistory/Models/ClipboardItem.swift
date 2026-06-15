import Foundation

struct ClipboardItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let content: ItemContent
    let timestamp: Date

    init(id: UUID = UUID(), content: ItemContent, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
    }
}

extension ClipboardItem: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, content, timestamp
    }

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.content = try c.decode(ItemContent.self, forKey: .content)
        self.timestamp = try c.decode(Date.self, forKey: .timestamp)
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(content, forKey: .content)
        try c.encode(timestamp, forKey: .timestamp)
    }
}

extension ItemContent: Sendable {}
