import SwiftUI
import PencilKit
import PDFKit

struct NoteDetailView: View {
    let note: Note
    
    @EnvironmentObject var noteStore: NoteStore
    @EnvironmentObject var graphViewModel: GraphViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingEditor = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 노트 이미지
                    noteImageView
                    
                    // 관련 개념 태그
                    if !relatedConcepts.isEmpty {
                        conceptTagsView
                    }
                    
                    // AI 분석 결과
                    if let description = note.description {
                        analysisView(description: description)
                    }
                    
                    // 메타 정보
                    metaInfoView
                }
                .padding()
            }
            .navigationTitle(note.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("편집") {
                        showingEditor = true
                    }
                }
            }
            .fullScreenCover(isPresented: $showingEditor) {
                if note.hasPDF {
                    PDFNoteEditorView(note: note) {
                        showingEditor = false
                    }
                    .environmentObject(noteStore)
                } else {
                    NoteEditorView(note: note) {
                        showingEditor = false
                    }
                    .environmentObject(noteStore)
                }
            }
        }
    }
    
    // MARK: - Note Image
    @ViewBuilder
    private var noteImageView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            
            if note.hasPDF, let pdfData = note.pdfData,
               let pdfDocument = PDFDocument(data: pdfData),
               let page = pdfDocument.page(at: 0) {
                Image(uiImage: page.thumbnail(of: CGSize(width: 400, height: 400), for: .mediaBox))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
            } else if !note.drawing.strokes.isEmpty {
                Image(uiImage: note.drawing.image(from: note.drawing.bounds, scale: 2.0))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
            } else {
                VStack {
                    Image(systemName: "pencil.tip")
                        .font(.system(size: 50))
                        .foregroundStyle(.tertiary)
                    Text("내용 없음")
                        .foregroundStyle(.secondary)
                }
                .frame(height: 200)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 200)
    }
    
    // MARK: - Concept Tags
    private var relatedConcepts: [Concept] {
        note.conceptIds.compactMap { id in
            graphViewModel.concepts.first { $0.id == id }
        }
    }
    
    private var conceptTagsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("관련 개념")
                .font(.headline)
            
            FlowLayout(spacing: 8) {
                ForEach(relatedConcepts) { concept in
                    ConceptTagView(concept: concept)
                }
            }
        }
    }
    
    // MARK: - Analysis View
    private func analysisView(description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain")
                    .foregroundStyle(.purple)
                Text("AI 분석")
                    .font(.headline)
            }
            
            Text(description)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
        }
    }
    
    // MARK: - Meta Info
    private var metaInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("정보")
                .font(.headline)
            
            HStack {
                Text("생성")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(note.createdAt.formatted(date: .long, time: .shortened))
            }
            .font(.subheadline)
            
            HStack {
                Text("수정")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(note.updatedAt.formatted(date: .long, time: .shortened))
            }
            .font(.subheadline)
            
            if note.hasPDF {
                HStack {
                    Text("유형")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Label("PDF 노트", systemImage: "doc.fill")
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Concept Tag View
struct ConceptTagView: View {
    let concept: Concept
    
    var body: some View {
        Text(concept.name)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .foregroundStyle(.blue)
            .cornerRadius(16)
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
                
                self.size.width = max(self.size.width, currentX)
            }
            
            self.size.height = currentY + lineHeight
        }
    }
}

#Preview {
    NoteDetailView(note: Note(title: "테스트 노트"))
        .environmentObject(NoteStore())
        .environmentObject(GraphViewModel())
}
