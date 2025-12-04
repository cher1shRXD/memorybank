import Foundation
import SwiftUI

struct Concept: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var description: String?
    var noteIds: [UUID]
    var createdAt: Date
    
    // 그래프 시각화용 위치 (Codable에서 제외)
    var position: CGPoint = .zero
    var velocity: CGPoint = .zero
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, noteIds, createdAt
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        noteIds: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.noteIds = noteIds
        self.createdAt = Date()
    }
    
    static func == (lhs: Concept, rhs: Concept) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Relation
struct Relation: Identifiable, Codable {
    let id: UUID
    let sourceId: UUID
    let targetId: UUID
    let type: RelationType
    var strength: Double
    
    init(
        id: UUID = UUID(),
        sourceId: UUID,
        targetId: UUID,
        type: RelationType,
        strength: Double = 1.0
    ) {
        self.id = id
        self.sourceId = sourceId
        self.targetId = targetId
        self.type = type
        self.strength = strength
    }
}

enum RelationType: String, Codable, CaseIterable {
    case requires = "REQUIRES"
    case contains = "CONTAINS"
    case leadsTo = "LEADS_TO"
    case related = "RELATED"
    
    var color: Color {
        switch self {
        case .requires: return .red
        case .contains: return .blue
        case .leadsTo: return .green
        case .related: return .gray
        }
    }
    
    var isDashed: Bool {
        self == .contains
    }
    
    var hasArrow: Bool {
        self == .requires || self == .leadsTo
    }
}
