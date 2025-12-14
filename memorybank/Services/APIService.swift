// Services/APIService.swift
import Foundation
import UIKit

// MARK: - Request Models
struct EmailRegisterRequest: Codable {
    let email: String
    let password: String
    let name: String
}

struct EmailLoginRequest: Codable {
    let email: String
    let password: String
}

struct GoogleAuthRequest: Codable {
    let id_token: String
}

struct RefreshTokenRequest: Codable {
    let refresh_token: String
}

struct ChatRequest: Codable {
    let message: String
}

struct NoteCreateRequest: Codable {
    let drawing_data: String?  // PencilKit drawing vector string
    let pdf_file: String?     // Base64 encoded PDF file
    let thumbnail: String     // Base64 encoded PNG thumbnail
}

struct NoteUpdateRequest: Codable {
    var drawing_data: String?  // PencilKit drawing vector string
    var pdf_file: String?     // Base64 encoded PDF file
    var thumbnail: String?
}

// MARK: - Response Models
struct UserResponse: Codable {
    let id: UUID
    let email: String
    let name: String
    let created_at: String?
}

struct TokenResponse: Codable {
    let access_token: String
    let refresh_token: String
    let user: UserResponse
}

struct AccessTokenResponse: Codable {
    let access_token: String
}

struct ChatSource: Codable, Identifiable {
    var id: UUID { note_id }
    let note_id: UUID
    let description: String
}

struct ChatResponse: Codable {
    let answer: String
    let sources: [ChatSource]?
}

struct ChatHistoryItem: Codable, Identifiable {
    let id: UUID
    let note_id: UUID?
    let question: String
    let answer: String
    let sources: [ChatSource]?
    let created_at: String
}

struct ConceptItem: Codable {
    let name: String
    let context: String
    let confidence: String  // "확실함"|"이해함"|"헷갈림"|"모름"
}

struct RelationItem: Codable {
    let from: String
    let to: String
    let type: String  // "REQUIRES"|"CONTAINS"|"LEADS_TO"|"RELATED"
    
    enum CodingKeys: String, CodingKey {
        case from
        case to
        case type
    }
}

struct NoteResponse: Codable, Identifiable {
    let id: UUID
    let drawing_data: String?   // PencilKit drawing vector string
    let pdf_url: String?        // PDF file URL
    let thumbnail_url: String?
    let description: String?
    let concepts: [[String: Any]]?  // Dynamic JSON array
    let relations: [[String: Any]]? // Dynamic JSON array
    let created_at: String
    let updated_at: String?     // Optional for create response
    
    // Custom decoding for dynamic JSON
    enum CodingKeys: String, CodingKey {
        case id, drawing_data, pdf_url, thumbnail_url, description
        case concepts, relations, created_at, updated_at
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        drawing_data = try container.decodeIfPresent(String.self, forKey: .drawing_data)
        pdf_url = try container.decodeIfPresent(String.self, forKey: .pdf_url)
        thumbnail_url = try container.decodeIfPresent(String.self, forKey: .thumbnail_url)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        created_at = try container.decode(String.self, forKey: .created_at)
        // updated_at might be missing in create response
        updated_at = try container.decodeIfPresent(String.self, forKey: .updated_at) ?? created_at
        
        // Handle dynamic JSON arrays
        if let conceptsData = try? container.decode([[String: AnyCodable]].self, forKey: .concepts) {
            concepts = conceptsData.map { dict in
                dict.mapValues { $0.value }
            }
        } else {
            concepts = nil
        }
        
        if let relationsData = try? container.decode([[String: AnyCodable]].self, forKey: .relations) {
            relations = relationsData.map { dict in
                dict.mapValues { $0.value }
            }
        } else {
            relations = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(drawing_data, forKey: .drawing_data)
        try container.encodeIfPresent(pdf_url, forKey: .pdf_url)
        try container.encodeIfPresent(thumbnail_url, forKey: .thumbnail_url)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(created_at, forKey: .created_at)
        try container.encodeIfPresent(updated_at, forKey: .updated_at)
    }
}

struct NoteListItem: Codable, Identifiable {
    let id: UUID
    let thumbnail_url: String?
    let description: String?
    let concepts: [[String: Any]]?  // Dynamic JSON array
    let created_at: String
    
    // Convenience init for creating from other sources
    init(id: UUID, thumbnail_url: String?, description: String?, concepts: [[String: Any]]?, created_at: String) {
        self.id = id
        self.thumbnail_url = thumbnail_url
        self.description = description
        self.concepts = concepts
        self.created_at = created_at
    }
    
    // Custom decoding for dynamic JSON
    enum CodingKeys: String, CodingKey {
        case id, thumbnail_url, description, concepts, created_at
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        thumbnail_url = try container.decodeIfPresent(String.self, forKey: .thumbnail_url)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        created_at = try container.decode(String.self, forKey: .created_at)
        
        // Handle dynamic JSON arrays
        if let conceptsData = try? container.decode([[String: AnyCodable]].self, forKey: .concepts) {
            concepts = conceptsData.map { dict in
                dict.mapValues { $0.value }
            }
        } else {
            concepts = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(thumbnail_url, forKey: .thumbnail_url)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(created_at, forKey: .created_at)
    }
}

struct HandwritingChatResponse: Codable {
    let question_text: String
    let answer: String
    let sources: [ChatSource]?
}

struct GraphNode: Codable, Identifiable {
    let id: String
    let name: String
    let type: String  // "Concept" or "Note"
}

struct GraphEdge: Codable, Identifiable {
    var id: String { "\(source)-\(target)-\(type)" }
    let source: String
    let target: String
    let type: String
}

struct GraphResponse: Codable {
    let nodes: [GraphNode]
    let edges: [GraphEdge]
}

struct ConceptCenter: Codable {
    let name: String
    let user_id: String
}

struct ConnectedConcept: Codable {
    let concept: String
    let relation: String
    let depth: Int
}

struct ConceptGraphResponse: Codable {
    let center: ConceptCenter
    let connected: [ConnectedConcept]
}

struct DeleteResponse: Codable {
    let success: Bool
    let message: String?
}

// MARK: - Empty Response
struct EmptyResponse: Codable {}

// MARK: - AnyCodable for dynamic properties
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = ""
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        }
    }
}

// MARK: - API Errors
enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidData
    case httpError(Int)
    case decodingError
    case unauthorized
    case validationError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다."
        case .invalidResponse:
            return "서버 응답이 올바르지 않습니다."
        case .invalidData:
            return "데이터 형식이 올바르지 않습니다."
        case .httpError(let code):
            return "HTTP 오류: \(code)"
        case .decodingError:
            return "데이터 파싱 오류입니다."
        case .unauthorized:
            return "인증이 필요합니다."
        case .validationError:
            return "입력값이 올바르지 않습니다."
        }
    }
}

// MARK: - API Service
class APIService {
    static let shared = APIService()
    
    // TODO: Update this to your actual API URL
    // For local development: "http://localhost:8000"
    // For production: "https://your-api-domain.com"
    private let baseURL = "https://d579b9d85d96.ngrok-free.app"
    private let keychain = KeychainService.shared
    
    private init() {}
    
    // MARK: - Auth
    func register(email: String, password: String, name: String) async throws -> TokenResponse {
        let body = EmailRegisterRequest(email: email, password: password, name: name)
        let response: TokenResponse = try await request(
            endpoint: "/auth/register",
            method: "POST",
            body: body,
            requiresAuth: false
        )
        
        keychain.accessToken = response.access_token
        keychain.refreshToken = response.refresh_token
        
        return response
    }
    
    func login(email: String, password: String) async throws -> TokenResponse {
        let body = EmailLoginRequest(email: email, password: password)
        let response: TokenResponse = try await request(
            endpoint: "/auth/login",
            method: "POST",
            body: body,
            requiresAuth: false
        )
        
        keychain.accessToken = response.access_token
        keychain.refreshToken = response.refresh_token
        
        return response
    }
    
    func googleAuth(idToken: String) async throws -> TokenResponse {
        let body = GoogleAuthRequest(id_token: idToken)
        let response: TokenResponse = try await request(
            endpoint: "/auth/google",
            method: "POST",
            body: body,
            requiresAuth: false
        )
        
        keychain.accessToken = response.access_token
        keychain.refreshToken = response.refresh_token
        
        return response
    }
    
    func refreshToken() async throws -> AccessTokenResponse {
        guard let refreshToken = keychain.refreshToken else {
            throw APIError.unauthorized
        }
        
        let body = RefreshTokenRequest(refresh_token: refreshToken)
        let response: AccessTokenResponse = try await request(
            endpoint: "/auth/refresh",
            method: "POST",
            body: body,
            requiresAuth: false
        )
        
        keychain.accessToken = response.access_token
        
        return response
    }
    
    func logout() {
        keychain.clearAll()
    }
    
    // MARK: - Notes
    func createNote(drawingData: String?, pdfData: Data?, thumbnail: UIImage) async throws -> NoteResponse {
        guard let thumbnailData = thumbnail.pngData() else {
            throw APIError.invalidData
        }
        
        let body = NoteCreateRequest(
            drawing_data: drawingData,
            pdf_file: pdfData?.base64EncodedString(),
            thumbnail: thumbnailData.base64EncodedString()
        )
        return try await request(
            endpoint: "/notes",
            method: "POST",
            body: body
        )
    }
    
    func listNotes() async throws -> [NoteListItem] {
        return try await request(endpoint: "/notes")
    }
    
    func getNote(id: UUID) async throws -> NoteResponse {
        return try await request(endpoint: "/notes/\(id.uuidString.lowercased())")
    }
    
    func getPDF(noteId: UUID) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/notes/\(noteId.uuidString.lowercased())/pdf") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        if let token = keychain.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        return data
    }
    
    func updateNote(id: UUID, drawingData: String? = nil, pdfData: Data? = nil, thumbnail: UIImage? = nil) async throws -> NoteResponse {
        var body = NoteUpdateRequest(drawing_data: nil, pdf_file: nil, thumbnail: nil)
        
        if let drawingData = drawingData {
            body.drawing_data = drawingData
        }
        
        if let pdfData = pdfData {
            body.pdf_file = pdfData.base64EncodedString()
        }
        
        if let thumbnail = thumbnail, let thumbnailData = thumbnail.pngData() {
            body.thumbnail = thumbnailData.base64EncodedString()
        }
        
        return try await request(
            endpoint: "/notes/\(id.uuidString.lowercased())",
            method: "PUT",
            body: body
        )
    }
    
    func deleteNote(id: UUID) async throws -> DeleteResponse {
        return try await request(
            endpoint: "/notes/\(id.uuidString.lowercased())",
            method: "DELETE"
        )
    }
    
    // MARK: - Chat
    func chat(message: String) async throws -> ChatResponse {
        let body = ChatRequest(message: message)
        return try await request(
            endpoint: "/chat",
            method: "POST",
            body: body
        )
    }
    
    func chatWithHandwriting(
        noteId: UUID,
        canvasImage: UIImage,
        questionBounds: CGRect
    ) async throws -> HandwritingChatResponse {
        guard let url = URL(string: "\(baseURL)/chat/handwriting") else {
            throw APIError.invalidURL
        }
        
        guard let imageData = canvasImage.jpegData(compressionQuality: 0.8) else {
            throw APIError.invalidData
        }
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        if let token = keychain.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        
        // note_id
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"note_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(noteId.uuidString.lowercased())\r\n".data(using: .utf8)!)
        
        // canvas_image
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"canvas_image\"; filename=\"canvas.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // question bounds
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"question_bounds_x\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(questionBounds.origin.x)\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"question_bounds_y\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(questionBounds.origin.y)\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"question_bounds_width\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(questionBounds.width)\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"question_bounds_height\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(questionBounds.height)\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            let tokenResponse = try await refreshToken()
            keychain.accessToken = tokenResponse.access_token
            return try await chatWithHandwriting(noteId: noteId, canvasImage: canvasImage, questionBounds: questionBounds)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(HandwritingChatResponse.self, from: data)
    }
    
    func getChatHistory(limit: Int = 20, offset: Int = 0) async throws -> [ChatHistoryItem] {
        let queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        return try await request(endpoint: "/chat/history", queryItems: queryItems)
    }
    
    // MARK: - Graph
    func getGraph() async throws -> GraphResponse {
        return try await request(endpoint: "/graph")
    }
    
    func getConceptGraph(name: String) async throws -> ConceptGraphResponse {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return try await request(endpoint: "/graph/concept/\(encodedName)")
    }
    
    // MARK: - Health
    func healthCheck() async throws -> Bool {
        let _: EmptyResponse = try await request(endpoint: "/health", requiresAuth: false)
        return true
    }
    
    // MARK: - File URLs
    func getThumbnailURL(for path: String) -> URL? {
        return URL(string: "\(baseURL)\(path)")
    }
    
    func getPDFURL(for path: String) -> URL? {
        return URL(string: "\(baseURL)\(path)")
    }
    
    func getFileData(from path: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        if let token = keychain.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        return data
    }
    
    // MARK: - Private Request Method
    private func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        queryItems: [URLQueryItem]? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        guard var urlComponents = URLComponents(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        if let queryItems = queryItems {
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if requiresAuth, let token = keychain.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            if httpResponse.statusCode == 204 || data.isEmpty {
                if let empty = EmptyResponse() as? T {
                    return empty
                }
            }
            
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                print("Decoding error: \(error)")
                print("Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw APIError.decodingError
            }
            
        case 401:
            if requiresAuth {
                do {
                    let tokenResponse = try await refreshToken()
                    // Update the access token for the retry
                    keychain.accessToken = tokenResponse.access_token
                    return try await self.request(
                        endpoint: endpoint,
                        method: method,
                        body: body,
                        queryItems: queryItems,
                        requiresAuth: true
                    )
                } catch {
                    keychain.clearAll()
                    throw APIError.unauthorized
                }
            }
            throw APIError.unauthorized
            
        case 422:
            throw APIError.validationError
            
        default:
            throw APIError.httpError(httpResponse.statusCode)
        }
    }
}