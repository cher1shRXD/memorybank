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
        print("[NoteStore] Creating new note...")
        let note = Note(drawing: drawing, pdfData: pdfData)
        
        await MainActor.run {
            notes.insert(note, at: 0)
        }
        
        print("[NoteStore] Saving note to server...")
        // Save to server and get updated note with server data
        if let updatedNote = await saveNoteToServer(note) {
            print("[NoteStore] Note saved successfully with ID: \(updatedNote.id)")
            return updatedNote
        }
        
        print("[NoteStore] Failed to save note to server")
        // If server save failed, return nil to prevent opening editor
        await MainActor.run {
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes.remove(at: index)
            }
        }
        
        return nil
    }
    
    // MARK: - Update Note (Save to Server)
    func updateNote(id: UUID, drawing: PKDrawing) async {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { 
            print("[NoteStore] updateNote - Note not found: \(id)")
            return 
        }
        
        print("[NoteStore] updateNote - Updating note: \(id), strokes: \(drawing.strokes.count)")
        
        // Update local cache
        await MainActor.run {
            notes[index].drawing = drawing
            notes[index].updatedAt = Date()
        }
        
        // Always update on server (both new and existing notes should have been created already)
        await updateNoteOnServer(id: id, drawing: drawing)
    }
    
    // MARK: - Save Note to Server
    func saveNoteToServer(_ note: Note) async -> Note? {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return nil }
        
        await MainActor.run { isLoading = true }
        
        do {
            // Generate thumbnail
            print("[NoteStore] Generating thumbnail...")
            let thumbnail = renderThumbnail(from: note.drawing)
            
            print("[NoteStore] Calling API to create note...")
            print("[NoteStore] Drawing data: \(note.drawingData?.prefix(50) ?? "nil")")
            print("[NoteStore] PDF data: \(note.pdfData != nil ? "Present" : "None")")
            
            // Send to server
            let response = try await api.createNote(
                drawingData: note.drawingData,
                pdfData: note.pdfData,
                thumbnail: thumbnail
            )
            
            print("[NoteStore] API Response received: \(response.id)")
            
            // Update with server response
            var updatedNote = Note(from: response)
            // Preserve local drawing cache and PDF data
            updatedNote.pdfData = note.pdfData
            
            // IMPORTANT: Preserve the original drawing data and cache
            if note.drawingData != nil {
                updatedNote.drawingData = note.drawingData
            }
            // Also set the drawing directly to preserve the PKDrawing object
            updatedNote.drawing = note.drawing
            
            print("[NoteStore] Updated note - drawing data: \(updatedNote.drawingData != nil), drawing strokes: \(updatedNote.drawing.strokes.count)")
            
            await MainActor.run {
                notes[index] = updatedNote
                isLoading = false
            }
            
            return updatedNote
        } catch {
            print("[NoteStore] Error saving note to server: \(error)")
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
            return nil
        }
    }
    
    // MARK: - Update Existing Note
    func updateNoteOnServer(id: UUID, drawing: PKDrawing) async {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { 
            print("[NoteStore] updateNoteOnServer - Note not found: \(id)")
            return 
        }
        
        print("[NoteStore] updateNoteOnServer - Starting update for: \(id)")
        
        do {
            // Generate thumbnail
            let thumbnail = renderThumbnail(from: drawing)
            
            // Convert drawing to base64 string
            let drawingData = drawing.dataRepresentation().base64EncodedString()
            
            print("[NoteStore] updateNoteOnServer - Drawing data size: \(drawingData.count)")
            
            // Server update
            let response = try await api.updateNote(
                id: id,
                drawingData: drawingData,  // Use the new drawing data
                pdfData: nil,  // Don't re-upload PDF
                thumbnail: thumbnail
            )
            
            print("[NoteStore] updateNoteOnServer - Server response received")
            
            await MainActor.run {
                // Update with server response
                var updatedNote = Note(from: response)
                // Preserve local data
                updatedNote.drawing = drawing  // Set the drawing directly
                updatedNote.pdfData = notes[index].pdfData
                notes[index] = updatedNote
                print("[NoteStore] updateNoteOnServer - Local note updated")
            }
        } catch {
            print("[NoteStore] updateNoteOnServer - Error: \(error)")
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
            
            var updatedNote = Note(from: response)
            updatedNote.pdfData = pdfData
            
            await MainActor.run {
                if let index = notes.firstIndex(where: { $0.id == note.id }) {
                    notes[index] = updatedNote
                }
                isLoading = false
            }
            
            return updatedNote
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