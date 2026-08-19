import Foundation

enum BurnerZone: String, Codable, CaseIterable, Identifiable, Sendable {
    case front = "front-burner"
    case back = "back-burner"
    case sink = "kitchen-sink"
    case unscheduled

    var id: String { rawValue }
    var title: String {
        switch self {
        case .front: "Front Burner"
        case .back: "Back Burner"
        case .sink: "Kitchen Sink"
        case .unscheduled: "Unscheduled"
        }
    }
}

struct BurnerListRow: Codable, Identifiable, Equatable, Sendable {
    var id: String { key }
    let userId: UUID
    let key: String
    let dateKey: String
    var frontName: String
    var backName: String
    var quote: String
    var updatedAt: Date
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case key, quote
        case userId = "user_id"
        case dateKey = "date_key"
        case frontName = "front_name"
        case backName = "back_name"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct BurnerTaskRow: Codable, Identifiable, Equatable, Sendable {
    let userId: UUID
    let id: String
    var listKey: String
    var zone: BurnerZone
    var text: String
    var done: Bool
    var sortOrder: Double
    var inProgress: Bool
    var boardOrder: Double
    var scheduledDate: String?
    var completedAt: Date?
    var updatedAt: Date
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, zone, text, done
        case userId = "user_id"
        case listKey = "list_key"
        case sortOrder = "sort_order"
        case inProgress = "in_progress"
        case boardOrder = "board_order"
        case scheduledDate = "scheduled_date"
        case completedAt = "completed_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

extension JSONDecoder {
    static var supabase: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) { return date }
            let standard = ISO8601DateFormatter()
            if let date = standard.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Invalid ISO-8601 timestamp: \(value)"
            )
        }
        return decoder
    }
}

extension JSONEncoder {
    static var supabase: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }
}

extension Date {
    static func burnerKey(for date: Date = Date(), calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
    }
}
