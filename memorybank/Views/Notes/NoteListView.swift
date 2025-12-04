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
                            let note = noteStore.createNote()
                            selectedNote = note
                            showingEditor = true
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
                        PDFNoteEditorView(note: note) {
                            showingEditor = false
                            selectedNote = nil
                        }
                        .environmentObject(noteStore)
                    } else {
                        NoteEditorView(note: note) {
                            showingEditor = false
                            selectedNote = nil
                        }
                        .environmentObject(noteStore)
                    }
                }
            }
            .sheet(item: $showingDetail) { note in
                NoteDetailView(note: note)
                    .environmentObject(noteStore)
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
                    let note = noteStore.createNote(title: fileName, pdfData: pdfData)
                    selectedNote = note
                    showingEditor = true
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
                    let note = noteStore.createNote()
                    selectedNote = note
                    showingEditor = true
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
        VStack(alignment: .leading, spacing: 8) {
            // 썸네일
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                
                thumbnailView
            }
            .frame(height: 160)
            .onTapGesture(perform: onTap)
            
            // 정보
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if note.hasPDF {
                        Image(systemName: "doc.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Text(note.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                
                Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
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
            VStack {
                Image(systemName: "pencil.tip")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
            }
        } else {
            Image(uiImage: note.drawing.image(from: note.drawing.bounds, scale: 1.0))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(8)
        }
    }
}

#Preview {
    NoteListView()
        .environmentObject(NoteStore())
}
