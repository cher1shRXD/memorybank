// ViewModels/ChatViewModel.swift
import SwiftUI
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let storage = StorageService.shared
    private let api = APIService.shared
    
    init() {
        loadMessages()
        
        if messages.isEmpty {
            let welcomeMessage = ChatMessage(
                content: "안녕하세요! 저는 메모리뱅크 AI 튜터입니다. 노트에 대해 궁금한 점이 있으시면 무엇이든 물어보세요.",
                isUser: false
            )
            messages.append(welcomeMessage)
            saveLocal()
        }
    }
    
    // MARK: - Load
    func loadMessages() {
        messages = storage.loadChatMessages()
    }
    
    func loadHistoryFromServer() async {
        do {
            let response = try await api.getQueryHistory()
            
            await MainActor.run {
                // 서버 히스토리를 ChatMessage로 변환
                for item in response.data.reversed() {
                    // 중복 체크
                    if !messages.contains(where: { $0.id == item.id }) {
                        let userMessage = ChatMessage(
                            id: UUID(),
                            content: item.question,
                            isUser: true,
                            referencedNoteIds: []
                        )
                        let aiMessage = ChatMessage(
                            id: item.id,
                            content: item.answer,
                            isUser: false,
                            referencedNoteIds: item.source_note_ids ?? []
                        )
                        messages.append(userMessage)
                        messages.append(aiMessage)
                    }
                }
                saveLocal()
            }
        } catch {
            // 무시 (로컬 데이터 사용)
        }
    }
    
    // MARK: - Send Message
    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let userMessage = ChatMessage(content: text, isUser: true)
        
        await MainActor.run {
            messages.append(userMessage)
            inputText = ""
            isLoading = true
            saveLocal()
        }
        
        do {
            let response = try await api.query(question: text, includeGraph: false, topK: 5)
            
            let aiMessage = ChatMessage(
                content: response.answer,
                isUser: false,
                referencedNoteIds: response.sources.map { $0.note_id }
            )
            
            await MainActor.run {
                messages.append(aiMessage)
                isLoading = false
                saveLocal()
            }
        } catch {
            await MainActor.run {
                let errorMsg = ChatMessage(
                    content: "죄송합니다. 오류가 발생했습니다: \(error.localizedDescription)",
                    isUser: false
                )
                messages.append(errorMsg)
                isLoading = false
                saveLocal()
            }
        }
    }
    
    // MARK: - Clear
    func clearChat() {
        messages = [
            ChatMessage(
                content: "대화가 초기화되었습니다. 무엇이든 물어보세요!",
                isUser: false
            )
        ]
        saveLocal()
    }
    
    // MARK: - Private
    private func saveLocal() {
        storage.saveChatMessages(messages)
    }
}
