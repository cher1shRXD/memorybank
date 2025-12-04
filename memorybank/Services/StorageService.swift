import Foundation

class StorageService {
    static let shared = StorageService()
    
    private let fileManager = FileManager.default
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var notesURL: URL {
        documentsDirectory.appendingPathComponent("notes.json")
    }
    
    private var conceptsURL: URL {
        documentsDirectory.appendingPathComponent("concepts.json")
    }
    
    private var relationsURL: URL {
        documentsDirectory.appendingPathComponent("relations.json")
    }
    
    private var chatMessagesURL: URL {
        documentsDirectory.appendingPathComponent("chat_messages.json")
    }
    
    private var strokeCacheDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("stroke_cache")
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
    
    private init() {}
    
    // MARK: - Notes
    func saveNotes(_ notes: [Note]) {
        save(notes, to: notesURL)
    }
    
    func loadNotes() -> [Note] {
        load(from: notesURL) ?? []
    }
    
    // MARK: - Concepts
    func saveConcepts(_ concepts: [Concept]) {
        save(concepts, to: conceptsURL)
    }
    
    func loadConcepts() -> [Concept] {
        load(from: conceptsURL) ?? []
    }
    
    // MARK: - Relations
    func saveRelations(_ relations: [Relation]) {
        save(relations, to: relationsURL)
    }
    
    func loadRelations() -> [Relation] {
        load(from: relationsURL) ?? []
    }
    
    // MARK: - Chat Messages
    func saveChatMessages(_ messages: [ChatMessage]) {
        save(messages, to: chatMessagesURL)
    }
    
    func loadChatMessages() -> [ChatMessage] {
        load(from: chatMessagesURL) ?? []
    }
    
    // MARK: - Stroke Cache (오프라인 편집용)
    func cacheStrokeData(_ data: Data, for noteId: UUID) {
        let url = strokeCacheDirectory.appendingPathComponent("\(noteId.uuidString).stroke")
        try? data.write(to: url)
    }
    
    func loadCachedStrokeData(for noteId: UUID) -> Data? {
        let url = strokeCacheDirectory.appendingPathComponent("\(noteId.uuidString).stroke")
        return try? Data(contentsOf: url)
    }
    
    func deleteCachedStrokeData(for noteId: UUID) {
        let url = strokeCacheDirectory.appendingPathComponent("\(noteId.uuidString).stroke")
        try? fileManager.removeItem(at: url)
    }
    
    // MARK: - Private Helpers
    private func save<T: Encodable>(_ object: T, to url: URL) {
        do {
            let data = try JSONEncoder().encode(object)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            print("저장 실패: \(error.localizedDescription)")
        }
    }
    
    private func load<T: Decodable>(from url: URL) -> T? {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }
}
