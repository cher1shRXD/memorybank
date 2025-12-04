// Views/Notes/PDFNoteEditorView.swift
import SwiftUI
import PencilKit
import PDFKit

struct PDFNoteEditorView: View {
    let note: Note
    let onDismiss: () -> Void
    
    @EnvironmentObject var noteStore: NoteStore
    @State private var currentPage = 0
    @State private var totalPages = 0
    @State private var title: String
    @State private var isEditingTitle = false
    @State private var canvasView = PKCanvasView()
    @State private var isSaving = false
    @State private var editorMode: EditorMode = .drawing
    
    // 질문 모드용
    @State private var drawingBeforeQuestion: PKDrawing?
    @State private var questionAnswer: String?
    @State private var showingAnswer = false
    
    init(note: Note, onDismiss: @escaping () -> Void) {
        self.note = note
        self.onDismiss = onDismiss
        self._title = State(initialValue: note.title)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            modeToggleView
            
            // PDF + 필기 영역
            if let pdfData = note.pdfData,
               let pdfDocument = PDFDocument(data: pdfData) {
                PDFCanvasView(
                    pdfDocument: pdfDocument,
                    currentPage: $currentPage,
                    canvasView: $canvasView,
                    onDrawingChanged: { pageDrawing in
                        if editorMode == .drawing {
                            noteStore.updatePageDrawing(id: note.id, page: currentPage, drawing: pageDrawing)
                        }
                    },
                    getPageDrawing: { page in
                        noteStore.getNote(id: note.id)?.getPageDrawing(page: page) ?? PKDrawing()
                    },
                    onPageChange: { newPage in
                        noteStore.updatePageDrawing(id: note.id, page: currentPage, drawing: canvasView.drawing)
                        currentPage = newPage
                    }
                )
                .onAppear {
                    totalPages = pdfDocument.pageCount
                }
            }
            
            Divider()
            
            pageIndicatorView
        }
        .sheet(isPresented: $showingAnswer) {
            answerSheet
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button("취소") {
                noteStore.updatePageDrawing(id: note.id, page: currentPage, drawing: canvasView.drawing)
                onDismiss()
            }
            
            Spacer()
            
            if isEditingTitle {
                TextField("제목", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                    .onSubmit {
                        noteStore.updateTitle(id: note.id, title: title)
                        isEditingTitle = false
                    }
            } else {
                Button {
                    isEditingTitle = true
                } label: {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.headline)
                        Image(systemName: "pencil")
                            .font(.caption)
                    }
                    .foregroundStyle(.primary)
                }
            }
            
            Spacer()
            
            Button {
                saveNote()
            } label: {
                if isSaving {
                    ProgressView()
                } else {
                    Text("저장")
                        .fontWeight(.semibold)
                }
            }
            .disabled(isSaving)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Mode Toggle
    @ViewBuilder
    private var modeToggleView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    switchToDrawingMode()
                } label: {
                    HStack {
                        Image(systemName: "pencil.tip")
                        Text("필기")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(editorMode == .drawing ? Color.blue : Color.clear)
                    .foregroundStyle(editorMode == .drawing ? .white : .primary)
                }
                
                Button {
                    switchToQuestionMode()
                } label: {
                    HStack {
                        Image(systemName: "questionmark.circle")
                        Text("질문")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(editorMode == .question ? Color.orange : Color.clear)
                    .foregroundStyle(editorMode == .question ? .white : .primary)
                }
            }
            .background(Color(.secondarySystemBackground))
            
            if editorMode == .question {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.orange)
                    Text("질문을 손글씨로 작성하세요")
                        .font(.caption)
                    
                    Spacer()
                    
                    Button("질문하기") {
                        submitQuestion()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.small)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
            }
        }
    }
    
    // MARK: - Page Indicator
    private var pageIndicatorView: some View {
        HStack {
            Button {
                if currentPage > 0 {
                    noteStore.updatePageDrawing(id: note.id, page: currentPage, drawing: canvasView.drawing)
                    currentPage -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
            }
            .disabled(currentPage == 0)
            
            Spacer()
            
            Text("\(currentPage + 1) / \(totalPages)")
                .font(.headline)
                .monospacedDigit()
            
            Spacer()
            
            Button {
                if currentPage < totalPages - 1 {
                    noteStore.updatePageDrawing(id: note.id, page: currentPage, drawing: canvasView.drawing)
                    currentPage += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title2)
            }
            .disabled(currentPage >= totalPages - 1)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Answer Sheet
    private var answerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("AI 답변")
                        .font(.headline)
                    
                    Text(questionAnswer ?? "답변을 가져오는 중...")
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("질문 답변")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("확인") {
                        showingAnswer = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - Actions
    private func switchToDrawingMode() {
        if editorMode == .question, let originalDrawing = drawingBeforeQuestion {
            canvasView.drawing = originalDrawing
            noteStore.updatePageDrawing(id: note.id, page: currentPage, drawing: originalDrawing)
        }
        editorMode = .drawing
    }
    
    private func switchToQuestionMode() {
        if editorMode == .drawing {
            drawingBeforeQuestion = canvasView.drawing
        }
        editorMode = .question
    }
    
    private func submitQuestion() {
        guard let originalDrawing = drawingBeforeQuestion else { return }
        
        let currentDrawing = canvasView.drawing
        let image = currentDrawing.image(from: canvasView.bounds, scale: 2.0)
        
        Task {
            do {
                let response = try await APIService.shared.askQuestion(
                    noteImage: image,
                    questionBounds: currentDrawing.bounds,
                    strokeData: currentDrawing.dataRepresentation()
                )
                
                await MainActor.run {
                    questionAnswer = response.answer
                    showingAnswer = true
                    canvasView.drawing = originalDrawing
                    noteStore.updatePageDrawing(id: note.id, page: currentPage, drawing: originalDrawing)
                    editorMode = .drawing
                }
            } catch {
                await MainActor.run {
                    questionAnswer = "오류: \(error.localizedDescription)"
                    showingAnswer = true
                }
            }
        }
    }
    
    private func saveNote() {
        isSaving = true
        noteStore.updatePageDrawing(id: note.id, page: currentPage, drawing: canvasView.drawing)
        
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                isSaving = false
                onDismiss()
            }
        }
    }
}

// MARK: - PDF Canvas View
struct PDFCanvasView: UIViewRepresentable {
    let pdfDocument: PDFDocument
    @Binding var currentPage: Int
    @Binding var canvasView: PKCanvasView
    var onDrawingChanged: ((PKDrawing) -> Void)?
    var getPageDrawing: (Int) -> PKDrawing
    var onPageChange: ((Int) -> Void)?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .gray
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(imageView)
        context.coordinator.imageView = imageView
        
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .pencilOnly
        canvasView.tool = PKInkingTool(.pen, color: .red, width: 3)
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.delegate = context.coordinator
        canvasView.drawing = getPageDrawing(currentPage)
        containerView.addSubview(canvasView)
        
        // 팬 제스처
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.delegate = context.coordinator
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1
        canvasView.addGestureRecognizer(panGesture)
        
        // 툴피커
        let toolPicker = PKToolPicker()
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
        context.coordinator.toolPicker = toolPicker
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            canvasView.topAnchor.constraint(equalTo: containerView.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
        
        context.coordinator.renderPage(currentPage)
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if context.coordinator.lastPage != currentPage {
            context.coordinator.renderPage(currentPage)
            canvasView.drawing = getPageDrawing(currentPage)
            context.coordinator.lastPage = currentPage
        }
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
        let parent: PDFCanvasView
        var toolPicker: PKToolPicker?
        var imageView: UIImageView?
        var lastPage: Int = 0
        
        private var startX: CGFloat = 0
        private var didChangePage = false
        private let swipeThreshold: CGFloat = 50
        
        init(parent: PDFCanvasView) {
            self.parent = parent
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            return touch.type == .direct
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            
            switch gesture.state {
            case .began:
                startX = translation.x
                didChangePage = false
                
            case .changed:
                if didChangePage { return }
                
                let deltaX = translation.x - startX
                
                if deltaX < -swipeThreshold {
                    goToNextPage()
                    didChangePage = true
                } else if deltaX > swipeThreshold {
                    goToPreviousPage()
                    didChangePage = true
                }
                
            case .ended, .cancelled:
                didChangePage = false
                
            default:
                break
            }
        }
        
        private func goToNextPage() {
            let totalPages = parent.pdfDocument.pageCount
            if parent.currentPage < totalPages - 1 {
                parent.onPageChange?(parent.currentPage + 1)
            }
        }
        
        private func goToPreviousPage() {
            if parent.currentPage > 0 {
                parent.onPageChange?(parent.currentPage - 1)
            }
        }
        
        func renderPage(_ pageIndex: Int) {
            guard let page = parent.pdfDocument.page(at: pageIndex),
                  let imageView = imageView else { return }
            
            let pageRect = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2.0
            let size = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
            
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { ctx in
                UIColor.white.set()
                ctx.fill(CGRect(origin: .zero, size: size))
                
                ctx.cgContext.translateBy(x: 0, y: size.height)
                ctx.cgContext.scaleBy(x: scale, y: -scale)
                
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            
            imageView.image = image
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.onDrawingChanged?(canvasView.drawing)
        }
    }
}
