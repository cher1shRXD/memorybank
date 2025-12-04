// ViewModels/NoteStore.swift
import SwiftUI
import PencilKit
import Combine

class NoteStore: ObservableObject {
    @Published var notes: [Note] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let storage = StorageService.shared
    private let api = APIService.shared
    
    init() {
        loadLocalNotes()
    }
    
    // MARK: - Load
    func loadLocalNotes() {
        notes = storage.loadNotes()
    }
    
    func fetchNotesFromServer() async {
        await MainActor.run { isLoading = true }
        
        do {
            let response = try await api.listNotes()
            
            await MainActor.run {
                for apiNote in response.data {
                    if let index = notes.firstIndex(where: { $0.id == apiNote.id }) {
                        notes[index].title = apiNote.title
                        notes[index].description = apiNote.content
                        notes[index].conceptIds = apiNote.concepts?.map { $0.id } ?? []
                    } else {
                        var newNote = Note(id: apiNote.id, title: apiNote.title)
                        newNote.description = apiNote.content
                        newNote.conceptIds = apiNote.concepts?.map { $0.id } ?? []
                        notes.append(newNote)
                    }
                }
                
                saveLocal()
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    // MARK: - Create
    func createNote(title: String = "새 노트", pdfData: Data? = nil) -> Note {
        let note = Note(
            title: title.isEmpty ? "노트 \(notes.count + 1)" : title,
            pdfData: pdfData
        )
        notes.insert(note, at: 0)
        saveLocal()
        return note
    }
    
    // MARK: - Update Local
    func updateNote(id: UUID, drawing: PKDrawing) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].drawing = drawing
        notes[index].updatedAt = Date()
        saveLocal()
    }
    
    func updatePageDrawing(id: UUID, page: Int, drawing: PKDrawing) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].setPageDrawing(page: page, drawing: drawing)
        notes[index].updatedAt = Date()
        saveLocal()
    }
    
    func updateTitle(id: UUID, title: String) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].title = title
        notes[index].updatedAt = Date()
        saveLocal()
    }
    
    // MARK: - Delete
    func deleteNote(id: UUID) {
        notes.removeAll { $0.id == id }
        storage.deleteCachedStrokeData(for: id)
        saveLocal()
        
        Task {
            try? await api.deleteNote(id: id)
        }
    }
    
    // MARK: - Get
    func getNote(id: UUID) -> Note? {
        notes.first { $0.id == id }
    }
    
    // MARK: - Save and Analyze
    func saveAndAnalyze(note: Note, image: UIImage) async {
        await MainActor.run { isLoading = true }
        
        do {
            // 이미지를 base64로 변환하거나 OCR 처리
            // 실제로는 이미지 업로드 API나 OCR API 필요
            let content = "필기 노트 내용"  // TODO: OCR 또는 이미지 처리
            
            let response = try await api.createNote(
                title: note.title,
                content: content,
                subject: nil
            )
            
            await MainActor.run {
                if let index = notes.firstIndex(where: { $0.id == note.id }) {
                    notes[index].description = response.content
                    notes[index].conceptIds = response.concepts?.map { $0.id } ?? []
                }
                saveLocal()
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    // MARK: - Private
    private func saveLocal() {
        storage.saveNotes(notes)
    }
}
