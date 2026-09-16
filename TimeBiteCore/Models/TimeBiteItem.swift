import Foundation

/// Common value semantics, not a persistence entity or polymorphic JSON envelope.
public protocol TimeBiteItem: Identifiable, Codable, Equatable, Sendable where ID == UUID {
    var id: UUID { get }
    var title: String { get set }
    var notes: String? { get set }
    var createdAt: Date { get }
    var updatedAt: Date { get set }
}
