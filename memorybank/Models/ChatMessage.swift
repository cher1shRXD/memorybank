import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    var referencedNoteIds: [UUID]
    
    init(
        id: UUID = UUID(),
        content: String,
        isUser: Bool,
        referencedNoteIds: [UUID] = []
    ) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
        self.referencedNoteIds = referencedNoteIds
    }
}
