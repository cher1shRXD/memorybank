// Services/APIService.swift
import Foundation
import UIKit

// MARK: - Request Models
struct UserCreate: Codable {
    let email: String
    let password: String
    let name: String
}

struct UserLogin: Codable {
    let email: String
    let password: String
}

struct RefreshTokenRequest: Codable {
    let refresh_token: String
}

struct NoteCreate: Codable {
    let title: String
    let content: String
    let subject: String?
    let note_type: String?
    
    init(title: String, content: String, subject: String? = nil, note_type: String? = "note") {
        self.title = title
        self.content = content
        self.subject = subject
        self.note_type = note_type
    }
}

struct NoteUpdate: Codable {
    let title: String?
    let content: String?
    let subject: String?
    let note_type: String?
}

struct QueryRequest: Codable {
    let question: String
    let include_graph: Bool
    let top_k: Int
    
    init(question: String, include_graph: Bool = false, top_k: Int = 5) {
        self.question = question
        self.include_graph = include_graph
        self.top_k = top_k
    }
}

// MARK: - Response Models
struct UserResponse: Codable {
    let id: UUID
    let email: String
    let name: String
    let created_at: String
}

struct TokenResponse: Codable {
    let access_token: String
    let refresh_token: String
    let user: UserResponse
}

struct PaginationMeta: Codable {
    let total: Int
    let page: Int
    let limit: Int
    let total_pages: Int
}

struct ConceptInNote: Codable, Identifiable {
    let id: UUID
    let name: String
    let category: String?
}

struct NoteAPIResponse: Codable, Identifiable {
    let id: UUID
    let title: String
    let content: String
    let subject: String?
    let note_type: String
    let concepts: [ConceptInNote]?
    let created_at: String
    let updated_at: String?
}

struct NoteListResponse: Codable {
    let data: [NoteAPIResponse]
    let meta: PaginationMeta
}

struct Source: Codable, Identifiable {
    var id: UUID { note_id }
    let note_id: UUID
    let title: String
    let content_preview: String
    let relevance: Double
}

struct RelatedConcept: Codable, Identifiable {
    let id: UUID
    let name: String
    let category: String?
}

struct QueryResponse: Codable {
    let answer: String
    let sources: [Source]
    let related_concepts: [RelatedConcept]?
}

struct QueryHistoryItem: Codable, Identifiable {
    let id: UUID
    let question: String
    let answer: String
    let source_note_ids: [UUID]?
    let created_at: String
}

struct QueryHistoryResponse: Codable {
    let data: [QueryHistoryItem]
    let meta: PaginationMeta
}

struct GraphNode: Codable, Identifiable {
    let id: String
    let type: String  // "concept" or "note"
    let label: String
    let properties: [String: AnyCodable]?
}

struct GraphEdge: Codable, Identifiable {
    var id: String { "\(source)-\(target)" }
    let source: String
    let target: String
    let type: String
    let weight: Double?
}

struct GraphResponse: Codable {
    let nodes: [GraphNode]
    let edges: [GraphEdge]
}

struct ConceptAPIResponse: Codable, Identifiable {
    let id: UUID
    let name: String
    let category: String?
    let mention_count: Int
    let created_at: String
}

struct ConceptListResponse: Codable {
    let data: [ConceptAPIResponse]
    let meta: PaginationMeta
}

struct TimelineNote: Codable, Identifiable {
    let id: UUID
    let title: String
    let created_at: String
}

struct ConceptTimelineResponse: Codable {
    let concept: ConceptAPIResponse
    let notes: [TimelineNote]
}

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

// MARK: - API Service
class APIService {
    static let shared = APIService()
    
    private let baseURL = "https://rosaura-priestless-cavally.ngrok-free.dev"
    private let keychain = KeychainService.shared
    
    private init() {}
    
    // MARK: - Auth
    func register(email: String, password: String, name: String) async throws -> UserResponse {
        let body = UserCreate(email: email, password: password, name: name)
        return try await request(
            endpoint: "/auth/register",
            method: "POST",
            body: body
        )
    }
    
    func login(email: String, password: String) async throws -> TokenResponse {
        let body = UserLogin(email: email, password: password)
        let response: TokenResponse = try await request(
            endpoint: "/auth/login",
            method: "POST",
            body: body
        )
        
        // 토큰 저장
        keychain.accessToken = response.access_token
        keychain.refreshToken = response.refresh_token
        
        return response
    }
    
    func refreshToken() async throws -> TokenResponse {
        guard let refreshToken = keychain.refreshToken else {
            throw APIError.unauthorized
        }
        
        let body = RefreshTokenRequest(refresh_token: refreshToken)
        let response: TokenResponse = try await request(
            endpoint: "/auth/refresh",
            method: "POST",
            body: body,
            requiresAuth: false
        )
        
        keychain.accessToken = response.access_token
        keychain.refreshToken = response.refresh_token
        
        return response
    }
    
    func logout() {
        keychain.clearAll()
    }
    
    // MARK: - Notes
    func createNote(title: String, content: String, subject: String? = nil) async throws -> NoteAPIResponse {
        let body = NoteCreate(title: title, content: content, subject: subject)
        return try await request(
            endpoint: "/notes",
            method: "POST",
            body: body
        )
    }
    
    func listNotes(
        page: Int = 1,
        limit: Int = 20,
        subject: String? = nil,
        search: String? = nil,
        sort: String = "-created_at"
    ) async throws -> NoteListResponse {
        var queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "sort", value: sort)
        ]
        
        if let subject = subject {
            queryItems.append(URLQueryItem(name: "subject", value: subject))
        }
        if let search = search {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        
        return try await request(endpoint: "/notes", queryItems: queryItems)
    }
    
    func getNote(id: UUID) async throws -> NoteAPIResponse {
        return try await request(endpoint: "/notes/\(id.uuidString)")
    }
    
    func updateNote(id: UUID, title: String? = nil, content: String? = nil, subject: String? = nil) async throws -> NoteAPIResponse {
        let body = NoteUpdate(title: title, content: content, subject: subject, note_type: nil)
        return try await request(
            endpoint: "/notes/\(id.uuidString)",
            method: "PUT",
            body: body
        )
    }
    
    func deleteNote(id: UUID) async throws {
        let _: EmptyResponse = try await request(
            endpoint: "/notes/\(id.uuidString)",
            method: "DELETE"
        )
    }
    
    // MARK: - Query (RAG)
    func query(question: String, includeGraph: Bool = false, topK: Int = 5) async throws -> QueryResponse {
        let body = QueryRequest(question: question, include_graph: includeGraph, top_k: topK)
        return try await request(
            endpoint: "/query",
            method: "POST",
            body: body
        )
    }
    
    func getQueryHistory(page: Int = 1, limit: Int = 20) async throws -> QueryHistoryResponse {
        let queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        return try await request(endpoint: "/query/history", queryItems: queryItems)
    }
    
    // MARK: - Graph
    func getUserGraph(depth: Int = 2, limit: Int = 100) async throws -> GraphResponse {
        let queryItems = [
            URLQueryItem(name: "depth", value: "\(depth)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        return try await request(endpoint: "/graph", queryItems: queryItems)
    }
    
    func getConceptGraph(name: String, depth: Int = 2) async throws -> GraphResponse {
        let queryItems = [
            URLQueryItem(name: "depth", value: "\(depth)")
        ]
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return try await request(endpoint: "/graph/concept/\(encodedName)", queryItems: queryItems)
    }
    
    func listConcepts(page: Int = 1, limit: Int = 20) async throws -> ConceptListResponse {
        let queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        return try await request(endpoint: "/concepts", queryItems: queryItems)
    }
    
    func getConceptTimeline(conceptId: UUID) async throws -> ConceptTimelineResponse {
        return try await request(endpoint: "/concepts/\(conceptId.uuidString)/timeline")
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
            // 204 No Content 처리
            if httpResponse.statusCode == 204 || data.isEmpty {
                if let empty = EmptyResponse() as? T {
                    return empty
                }
            }
            
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                print("Decoding error: \(error)")
                throw APIError.decodingError
            }
            
        case 401:
            // 토큰 만료 시 갱신 시도
            if requiresAuth {
                do {
                    _ = try await refreshToken()
                    // 재시도
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

// MARK: - Empty Response
struct EmptyResponse: Codable {}

// MARK: - API Errors
enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
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

// MARK: - Handwriting Question (로컬 처리용)
struct HandwritingQuestionResponse: Codable {
    let answer: String
    let referencedNoteIds: [UUID]
}

extension APIService {
    // 손글씨 질문 - Query API 활용
    func askQuestion(
        noteImage: UIImage,
        questionBounds: CGRect,
        strokeData: Data
    ) async throws -> HandwritingQuestionResponse {
        // 이미지에서 텍스트 추출 (실제로는 OCR 또는 서버 처리 필요)
        // 여기서는 Query API를 사용
        let question = "이미지 기반 질문"  // TODO: OCR 처리
        
        let response = try await query(question: question, includeGraph: false, topK: 5)
        
        return HandwritingQuestionResponse(
            answer: response.answer,
            referencedNoteIds: response.sources.map { $0.note_id }
        )
    }
}
