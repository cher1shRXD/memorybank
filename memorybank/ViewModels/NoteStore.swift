// ViewModels/NoteStore.swift
import SwiftUI
import PencilKit
import Combine

class NoteStore: ObservableObject {
    @Published var notes: [Note] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let api = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        Task {
            await fetchNotes()
        }
    }
    
    // MARK: - Fetch Notes
    func fetchNotes() async {
        await MainActor.run { isLoading = true }
        
        do {
            let response = try await api.listNotes()
            
            await MainActor.run {
                self.notes = response.map { Note(from: $0) }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    // MARK: - Create Note
    func createNote(drawing: PKDrawing = PKDrawing(), pdfData: Data? = nil) async -> Note? {
        let note = Note(drawing: drawing, pdfData: pdfData)
        
        await MainActor.run {
            notes.insert(note, at: 0)
        }
        
        // Save to server immediately
        await saveNoteToServer(note)
        
        return note
    }
    
    // MARK: - Update Note (Save to Server)
    func updateNote(id: UUID, drawing: PKDrawing) async {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        
        // Update local cache
        await MainActor.run {
            notes[index].drawing = drawing
            notes[index].updatedAt = Date()
        }
        
        // Save or update on server
        if notes[index].thumbnailUrl == nil {
            // New note - create on server
            await saveNoteToServer(notes[index])
        } else {
            // Existing note - update on server
            await updateNoteOnServer(id: id, drawing: drawing)
        }
    }
    
    // MARK: - Save Note to Server
    func saveNoteToServer(_ note: Note) async {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        
        await MainActor.run { isLoading = true }
        
        do {
            // Generate thumbnail
            let thumbnail = renderThumbnail(from: note.drawing)
            
            // Send to server
            let response = try await api.createNote(
                drawingData: note.drawingData,
                pdfData: note.pdfData,
                thumbnail: thumbnail
            )
            
            await MainActor.run {
                // Update with server response
                var updatedNote = Note(from: response)
                // Preserve local drawing cache
                updatedNote.drawingCache = note.drawing
                updatedNote.pdfData = note.pdfData
                notes[index] = updatedNote
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    // MARK: - Update Existing Note
    func updateNoteOnServer(id: UUID, drawing: PKDrawing) async {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        
        do {
            // Generate thumbnail
            let thumbnail = renderThumbnail(from: drawing)
            
            // Server update
            let response = try await api.updateNote(
                id: id,
                drawingData: notes[index].drawingData,
                pdfData: nil,  // Don't re-upload PDF
                thumbnail: thumbnail
            )
            
            await MainActor.run {
                // Update with server response
                var updatedNote = Note(from: response)
                // Preserve local data
                updatedNote.drawingCache = drawing
                updatedNote.pdfData = notes[index].pdfData
                notes[index] = updatedNote
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Delete Note
    func deleteNote(id: UUID) {
        // Remove locally first
        notes.removeAll { $0.id == id }
        
        // Delete from server
        Task {
            do {
                _ = try await api.deleteNote(id: id)
            } catch {
                // Re-fetch on failure
                await fetchNotes()
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Get Note
    func getNote(id: UUID) -> Note? {
        notes.first { $0.id == id }
    }
    
    // MARK: - Load Full Note Details
    func loadFullNoteDetails(_ noteId: UUID) async {
        do {
            let response = try await api.getNote(id: noteId)
            
            await MainActor.run {
                if let index = notes.firstIndex(where: { $0.id == noteId }) {
                    var updatedNote = Note(from: response)
                    // Preserve local data
                    updatedNote.drawingCache = notes[index].drawing
                    updatedNote.pdfData = notes[index].pdfData
                    notes[index] = updatedNote
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Load PDF
    func loadPDFForNote(_ noteId: UUID) async {
        guard let index = notes.firstIndex(where: { $0.id == noteId }),
              notes[index].pdfUrl != nil,
              notes[index].pdfData == nil else { return }
        
        do {
            let pdfData = try await api.getPDF(noteId: noteId)
            
            await MainActor.run {
                notes[index].pdfData = pdfData
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Upload PDF Note
    func uploadPDFNote(pdfData: Data) async -> Note? {
        // Create note with PDF
        let note = Note(drawing: PKDrawing(), pdfData: pdfData)
        
        await MainActor.run {
            notes.insert(note, at: 0)
        }
        
        await MainActor.run { isLoading = true }
        
        do {
            // For PDF notes, use a blank canvas as thumbnail for now
            let thumbnail = UIImage(systemName: "doc.fill") ?? UIImage()
            
            let response = try await api.createNote(
                drawingData: nil,
                pdfData: pdfData,
                thumbnail: thumbnail
            )
            
            await MainActor.run {
                if let index = notes.firstIndex(where: { $0.id == note.id }) {
                    var updatedNote = Note(from: response)
                    updatedNote.pdfData = pdfData
                    notes[index] = updatedNote
                }
                isLoading = false
            }
            
            return note
        } catch {
            await MainActor.run {
                // Remove the note on failure
                notes.removeAll { $0.id == note.id }
                errorMessage = error.localizedDescription
                isLoading = false
            }
            return nil
        }
    }
    
    // MARK: - Render Thumbnail
    private func renderThumbnail(from drawing: PKDrawing) -> UIImage {
        let bounds = drawing.bounds.isEmpty ? CGRect(x: 0, y: 0, width: 800, height: 600) : drawing.bounds
        
        // Limit max size for server performance
        let maxDimension: CGFloat = 400
        let scale = min(1.0, min(maxDimension / bounds.width, maxDimension / bounds.height))
        
        let scaledSize = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )
        
        return drawing.image(from: CGRect(origin: .zero, size: scaledSize), scale: 2.0)
    }
    
    // MARK: - Search Notes
    func searchNotes(query: String) -> [Note] {
        guard !query.isEmpty else { return notes }
        
        return notes.filter { note in
            if let description = note.description {
                return description.localizedCaseInsensitiveContains(query)
            }
            
            // Search in concepts
            for concept in note.parsedConcepts {
                if concept.name.localizedCaseInsensitiveContains(query) ||
                   concept.context.localizedCaseInsensitiveContains(query) {
                    return true
                }
            }
            
            return false
        }
    }
    
    // MARK: - Filter by Concept
    func filterByConcept(_ conceptName: String) -> [Note] {
        notes.filter { note in
            note.parsedConcepts.contains { $0.name == conceptName }
        }
    }
    
    // MARK: - Get Related Notes
    func getRelatedNotes(to noteId: UUID) -> [Note] {
        guard let note = getNote(id: noteId) else { return [] }
        
        let conceptNames = Set(note.parsedConcepts.map { $0.name })
        
        return notes.filter { otherNote in
            otherNote.id != noteId &&
            !Set(otherNote.parsedConcepts.map { $0.name }).isDisjoint(with: conceptNames)
        }
    }
}