import Foundation

struct ClipboardItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let content: ItemContent
    let timestamp: Date
    var isPinned: Bool

    init(id: UUID = UUID(), content: ItemContent, timestamp: Date = Date(), isPinned: Bool = false) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.isPinned = isPinned
    }
}

extension ClipboardItem: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, content, timestamp, isPinned
    }

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.content = try c.decode(ItemContent.self, forKey: .content)
        self.timestamp = try c.decode(Date.self, forKey: .timestamp)
        self.isPinned = (try? c.decode(Bool.self, forKey: .isPinned)) ?? false
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(content, forKey: .content)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encode(isPinned, forKey: .isPinned)
    }
}

extension ItemContent: Sendable {}
