import Foundation
import PencilKit

struct Note: Identifiable, Codable {
    let id: UUID
    var drawingData: String?          // PencilKit drawing vector string from API
    var pdfData: Data?               // Local PDF data
    var pdfUrl: String?              // PDF URL from API
    var thumbnailUrl: String?        // Thumbnail URL from API
    var description: String?         // AI-generated description
    var concepts: [[String: Any]]?   // Dynamic JSON array from API
    var relations: [[String: Any]]?  // Dynamic JSON array from API
    var createdAt: Date
    var updatedAt: Date
    var title: String                // Add title property
    
    // Local drawing cache for PencilKit - not codable
    var drawingCache: PKDrawing? {
        get {
            if let data = drawingData,
               let drawingDataDecoded = Data(base64Encoded: data),
               let drawing = try? PKDrawing(data: drawingDataDecoded) {
                return drawing
            }
            return nil
        }
        set {
            // Do not store the cache
        }
    }
    
    // Computed property for PKDrawing
    var drawing: PKDrawing {
        get {
            return drawingCache ?? PKDrawing()
        }
        set {
            // Convert PKDrawing to vector string representation
            drawingData = Self.convertDrawingToVectorString(newValue)
        }
    }
    
    // Check if note has PDF
    var hasPDF: Bool {
        return pdfData != nil || pdfUrl != nil
    }
    
    // Helper to convert PKDrawing to vector string
    private static func convertDrawingToVectorString(_ drawing: PKDrawing) -> String {
        // This is a placeholder - actual implementation would convert
        // PKDrawing strokes to a vector string format
        // For now, we'll store the base64 representation
        let data = drawing.dataRepresentation()
        return data.base64EncodedString()
    }
    
    // Helper to parse concepts
    var parsedConcepts: [ConceptInfo] {
        guard let concepts = concepts else { return [] }
        return concepts.compactMap { dict in
            guard let name = dict["name"] as? String,
                  let context = dict["context"] as? String,
                  let confidence = dict["confidence"] as? String else { return nil }
            return ConceptInfo(name: name, context: context, confidence: confidence)
        }
    }
    
    // Helper to parse relations
    var parsedRelations: [RelationInfo] {
        guard let relations = relations else { return [] }
        return relations.compactMap { dict in
            guard let from = dict["from"] as? String,
                  let to = dict["to"] as? String,
                  let type = dict["type"] as? String else { return nil }
            return RelationInfo(from: from, to: to, type: type)
        }
    }
    
    init(
        id: UUID = UUID(),
        drawing: PKDrawing = PKDrawing(),
        pdfData: Data? = nil
    ) {
        self.id = id
        self.drawingData = nil
        self.pdfData = pdfData
        self.pdfUrl = nil
        self.thumbnailUrl = nil
        self.description = nil
        self.concepts = nil
        self.relations = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        // Convert the drawing to data
        self.drawingData = Self.convertDrawingToVectorString(drawing)
        self.title = ""  // Default title
    }
    
    // Create from API response
    init(from apiResponse: NoteResponse) {
        self.id = apiResponse.id
        self.drawingData = apiResponse.drawing_data
        self.pdfData = nil  // Will be downloaded separately if needed
        self.pdfUrl = apiResponse.pdf_url
        self.thumbnailUrl = apiResponse.thumbnail_url
        self.description = apiResponse.description
        self.concepts = apiResponse.concepts
        self.relations = apiResponse.relations
        
        // Parse dates
        let formatter = ISO8601DateFormatter()
        self.createdAt = formatter.date(from: apiResponse.created_at) ?? Date()
        if let updated_at = apiResponse.updated_at {
            self.updatedAt = formatter.date(from: updated_at) ?? self.createdAt
        } else {
            self.updatedAt = self.createdAt
        }
        
        // drawingCache is computed
        self.title = apiResponse.description ?? "Untitled"
    }
    
    // Create from list item
    init(from listItem: NoteListItem) {
        self.id = listItem.id
        self.drawingData = nil
        self.pdfData = nil
        self.pdfUrl = nil
        self.thumbnailUrl = listItem.thumbnail_url
        self.description = listItem.description
        self.concepts = listItem.concepts
        self.relations = nil
        
        let formatter = ISO8601DateFormatter()
        self.createdAt = formatter.date(from: listItem.created_at) ?? Date()
        self.updatedAt = self.createdAt
        // drawingCache is computed
        self.title = listItem.description ?? "Untitled"
    }
    
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, drawingData, pdfData, pdfUrl, thumbnailUrl
        case description, createdAt, updatedAt, title
        // concepts and relations are not included because they contain Any type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        drawingData = try container.decodeIfPresent(String.self, forKey: .drawingData)
        pdfData = try container.decodeIfPresent(Data.self, forKey: .pdfData)
        pdfUrl = try container.decodeIfPresent(String.self, forKey: .pdfUrl)
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        
        // concepts and relations are not decoded from storage
        concepts = nil
        relations = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(drawingData, forKey: .drawingData)
        try container.encodeIfPresent(pdfData, forKey: .pdfData)
        try container.encodeIfPresent(pdfUrl, forKey: .pdfUrl)
        try container.encodeIfPresent(thumbnailUrl, forKey: .thumbnailUrl)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(title, forKey: .title)
    }
}

// Helper structures for parsing dynamic JSON
struct ConceptInfo {
    let name: String
    let context: String
    let confidence: String
}

struct RelationInfo {
    let from: String
    let to: String
    let type: String
}