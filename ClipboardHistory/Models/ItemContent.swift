import Foundation

enum ItemContent: Equatable {
    case text(String)
    case image(filename: String)
    case files([URL])
}

extension ItemContent: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, value
    }

    private enum Discriminator: String, Codable {
        case text, image, files
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(Discriminator.self, forKey: .type)
        switch type {
        case .text:
            self = .text(try container.decode(String.self, forKey: .value))
        case .image:
            self = .image(filename: try container.decode(String.self, forKey: .value))
        case .files:
            self = .files(try container.decode([URL].self, forKey: .value))
        }
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let value):
            try container.encode(Discriminator.text, forKey: .type)
            try container.encode(value, forKey: .value)
        case .image(let filename):
            try container.encode(Discriminator.image, forKey: .type)
            try container.encode(filename, forKey: .value)
        case .files(let urls):
            try container.encode(Discriminator.files, forKey: .type)
            try container.encode(urls, forKey: .value)
        }
    }
}
