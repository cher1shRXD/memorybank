import SwiftUI
import PencilKit

struct NoteDetailView: View {
    let noteId: UUID
    @State private var note: NoteResponse?
    @State private var drawingData: String?
    @State private var pdfData: Data?
    
    @EnvironmentObject var noteStore: NoteStore
    @EnvironmentObject var graphViewModel: GraphViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingEditor = false
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle("노트 상세")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("닫기") {
                                dismiss()
                            }
                        }
                    }
            } else if let note = note {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 노트 이미지
                        noteImageView
                        
                        // 관련 개념 태그
                        if let concepts = note.concepts, !concepts.isEmpty {
                            conceptTagsView(concepts: concepts)
                        }

                        // AI 분석 겳과
                        if let description = note.description {
                            analysisView(description: description)
                        }
                        
                        // 메타 정보
                        metaInfoView
                    }
                    .padding()
                }
                .navigationTitle("노트 상세")
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
            } else {
                ContentUnavailableView("노트를 불러올 수 없습니다", systemImage: "exclamationmark.triangle")
                    .navigationTitle("노트 상세")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("닫기") {
                                dismiss()
                            }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showingEditor) {
            if let note = note {
                if note.pdf_url != nil {
                    PDFNoteEditorView(noteId: noteId, pdfData: pdfData) {
                        showingEditor = false
                        Task {
                            await loadNote()
                        }
                    }
                    .environmentObject(noteStore)
                } else {
                    NoteEditorView(noteId: noteId) {
                        showingEditor = false
                        Task {
                            await loadNote()
                        }
                    }
                    .environmentObject(noteStore)
                }
            }
        }
        .task {
            await loadNote()
        }
    }
    
    // MARK: - Note Image
    @ViewBuilder
    private var noteImageView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            
            if let drawingData = drawingData,
               let drawingDataDecoded = Data(base64Encoded: drawingData),
               let drawing = try? PKDrawing(data: drawingDataDecoded),
               !drawing.strokes.isEmpty {
                Image(uiImage: drawing.image(from: drawing.bounds, scale: 2.0))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
            } else if let thumbnailUrl = note?.thumbnail_url,
                      let url = APIService.shared.getThumbnailURL(for: thumbnailUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding()
                    case .empty:
                        ProgressView()
                            .frame(height: 200)
                    case .failure(_):
                        emptyStateView
                    @unknown default:
                        emptyStateView
                    }
                }
            } else {
                emptyStateView
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 200)
    }
    
    private var emptyStateView: some View {
        VStack {
            Image(systemName: "pencil.tip")
                .font(.system(size: 50))
                .foregroundStyle(.tertiary)
            Text("내용 없음")
                .foregroundStyle(.secondary)
        }
        .frame(height: 200)
    }
    
    // MARK: - Concept Tags
    private func conceptTagsView(concepts: [[String: Any]]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("관련 개념")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            FlowLayout(spacing: 8) {
                ForEach(concepts.indices, id: \.self) { index in
                    let concept = concepts[index]
                    if let name = concept["name"] as? String,
                       let confidence = concept["confidence"] as? String {
                        Button {
                            Task {
                                await graphViewModel.fetchConceptGraph(name: name)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "tag.fill")
                                    .font(.caption)
                                Text(name)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(confidenceColor(for: confidence).opacity(0.1))
                            .foregroundStyle(confidenceColor(for: confidence))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Analysis View
    private func analysisView(description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.purple)
                Text("AI 분석 결과")
                    .font(.headline)
            }
            
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    // MARK: - Meta Info
    private var metaInfoView: some View {
        Group {
            if let note = note,
               let createdDate = ISO8601DateFormatter().date(from: note.created_at),
               let updatedDate = ISO8601DateFormatter().date(from: note.updated_at) {
                VStack(alignment: .leading, spacing: 12) {
                    Label {
                        Text(createdDate, style: .date)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                    }
                    
                    if updatedDate > createdDate {
                        Label {
                            Text(updatedDate, style: .relative)
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: "clock")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .font(.callout)
            }
        }
    }
    
    // MARK: - Confidence Color
    private func confidenceColor(for confidence: String) -> Color {
        switch confidence {
        case "확실함":
            return .green
        case "이해함":
            return .blue
        case "헷갈림":
            return .orange
        case "모름":
            return .red
        default:
            return .gray
        }
    }
    
    private func loadNote() async {
        isLoading = true
        do {
            let noteResponse = try await APIService.shared.getNote(id: noteId)
            self.note = noteResponse
            self.drawingData = noteResponse.drawing_data
            
            // Load PDF if available
            if noteResponse.pdf_url != nil {
                self.pdfData = try await APIService.shared.getPDF(noteId: noteId)
            }
            
            isLoading = false
        } catch {
            print("Error loading note: \(error)")
            isLoading = false
        }
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        
        for (index, frame) in result.frames.enumerated() {
            let adjustedFrame = frame.offsetBy(dx: bounds.minX, dy: bounds.minY)
            subviews[index].place(
                at: adjustedFrame.origin,
                proposal: ProposedViewSize(adjustedFrame.size)
            )
        }
    }
    
    struct FlowResult {
        let size: CGSize
        let frames: [CGRect]
        
        init(in containerWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var frames: [CGRect] = []
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            var maxWidth: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > containerWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
                maxWidth = max(maxWidth, currentX - spacing)
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
            self.frames = frames
        }
    }
}