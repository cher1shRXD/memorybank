import SwiftUI
import PencilKit
import PDFKit
import UniformTypeIdentifiers

struct NoteListView: View {
    @EnvironmentObject var noteStore: NoteStore
    @State private var selectedNote: Note?
    @State private var showingEditor = false
    @State private var showingFilePicker = false
    @State private var showingDetail: Note?
    
    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            Group {
                if noteStore.notes.isEmpty {
                    emptyStateView
                } else {
                    noteGridView
                }
            }
            .navigationTitle("내 노트")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            Task {
                                if let note = await noteStore.createNote() {
                                    await MainActor.run {
                                        selectedNote = note
                                        showingEditor = true
                                    }
                                }
                            }
                        } label: {
                            Label("새 노트", systemImage: "pencil")
                        }
                        
                        Button {
                            showingFilePicker = true
                        } label: {
                            Label("PDF 불러오기", systemImage: "doc.fill")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [UTType.pdf],
                allowsMultipleSelection: false
            ) { result in
                handlePDFImport(result)
            }
            .fullScreenCover(isPresented: $showingEditor) {
                if let note = selectedNote {
                    if note.hasPDF {
                        PDFNoteEditorView(noteId: note.id, pdfData: note.pdfData) {
                            showingEditor = false
                            selectedNote = nil
                        }
                        .environmentObject(noteStore)
                    } else {
                        NoteEditorView(noteId: note.id) {
                            showingEditor = false
                            selectedNote = nil
                        }
                        .environmentObject(noteStore)
                    }
                }
            }
            .sheet(item: $showingDetail) { note in
                NoteDetailView(noteId: note.id)
                    .environmentObject(noteStore)
                    .environmentObject(GraphViewModel())
            }
        }
    }
    
    private func handlePDFImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                
                if let pdfData = try? Data(contentsOf: url) {
                    let fileName = url.deletingPathExtension().lastPathComponent
                    Task {
                        let note = await noteStore.createNote(pdfData: pdfData)
                        await MainActor.run {
                            selectedNote = note
                            showingEditor = true
                        }
                    }
                }
            }
        case .failure(let error):
            print("PDF 불러오기 실패: \(error.localizedDescription)")
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "note.text")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("노트가 없습니다")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("새 노트를 추가하거나 PDF를 불러오세요")
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                Button {
                    Task {
                        if let note = await noteStore.createNote() {
                            await MainActor.run {
                                selectedNote = note
                                showingEditor = true
                            }
                        }
                    }
                } label: {
                    Label("새 노트", systemImage: "pencil")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    showingFilePicker = true
                } label: {
                    Label("PDF 불러오기", systemImage: "doc.fill")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var noteGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(noteStore.notes) { note in
                    NoteCardView(note: note) {
                        showingDetail = note
                    } onEdit: {
                        selectedNote = note
                        showingEditor = true
                    } onDelete: {
                        withAnimation {
                            noteStore.deleteNote(id: note.id)
                        }
                    }
                }
            }
            .padding()
        }
        .refreshable {
            await noteStore.fetchNotes()
        }
    }
}

// MARK: - Note Card View
struct NoteCardView: View {
    let note: Note
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                thumbnailView
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        if note.hasPDF {
                            Image(systemName: "doc.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        Text(note.title)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    
                    if let concepts = note.concepts, !concepts.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(concepts.prefix(2).indices, id: \.self) { index in
                                if let name = concepts[index]["name"] as? String {
                                    Text(name)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundStyle(.blue)
                                        .clipShape(Capsule())
                                }
                            }
                            if concepts.count > 2 {
                                Text("+\(concepts.count - 2)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
        }
        .buttonStyle(CardButtonStyle())
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("편집", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
        .alert("노트 삭제", isPresented: $showingDeleteAlert) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive, action: onDelete)
        } message: {
            Text("'\(note.title)'을(를) 삭제하시겠습니까?")
        }
    }
    
    @ViewBuilder
    private var thumbnailView: some View {
        if note.hasPDF, let pdfData = note.pdfData,
           let pdfDocument = PDFDocument(data: pdfData),
           let page = pdfDocument.page(at: 0) {
            Image(uiImage: page.thumbnail(of: CGSize(width: 160, height: 160), for: .mediaBox))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(8)
        } else if note.drawing.strokes.isEmpty {
            if let thumbnailUrl = note.thumbnailUrl,
               let url = URL(string: thumbnailUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(8)
                    case .empty:
                        ProgressView()
                    case .failure(_):
                        emptyThumbnail
                    @unknown default:
                        emptyThumbnail
                    }
                }
            } else {
                emptyThumbnail
            }
        } else {
            Image(uiImage: note.drawing.image(from: note.drawing.bounds, scale: 2.0))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(8)
        }
    }
    
    private var emptyThumbnail: some View {
        VStack {
            Image(systemName: "pencil.tip")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("내용 없음")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Card Button Style
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray3), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}