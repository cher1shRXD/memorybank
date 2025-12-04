// Views/Notes/NoteEditorView.swift
import SwiftUI
import PencilKit

enum EditorMode {
    case drawing
    case question
}

struct NoteEditorView: View {
    let note: Note
    let onDismiss: () -> Void
    
    @EnvironmentObject var noteStore: NoteStore
    @State private var canvasView = PKCanvasView()
    @State private var title: String
    @State private var isEditingTitle = false
    @State private var editorMode: EditorMode = .drawing
    @State private var isSaving = false
    
    // 질문 모드용
    @State private var drawingBeforeQuestion: PKDrawing?
    @State private var questionAnswer: String?
    @State private var showingAnswer = false
    @State private var isAskingQuestion = false
    
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
            
            NoteCanvasView(
                canvasView: $canvasView,
                initialDrawing: note.drawing,
                onDrawingChanged: { drawing in
                    if editorMode == .drawing {
                        noteStore.updateNote(id: note.id, drawing: drawing)
                    }
                }
            )
        }
        .sheet(isPresented: $showingAnswer) {
            answerSheet
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button("취소") {
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
                        .progressViewStyle(CircularProgressViewStyle())
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
                        Text("필기 모드")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(editorMode == .drawing ? Color.blue : Color.clear)
                    .foregroundStyle(editorMode == .drawing ? .white : .primary)
                }
                
                Button {
                    switchToQuestionMode()
                } label: {
                    HStack {
                        Image(systemName: "questionmark.circle")
                        Text("질문 모드")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(editorMode == .question ? Color.orange : Color.clear)
                    .foregroundStyle(editorMode == .question ? .white : .primary)
                }
            }
            .background(Color(.secondarySystemBackground))
            
            if editorMode == .question {
                HStack {
                    Image(systemName: "info.circle")
                    Text("질문을 손글씨로 작성하고 '질문하기' 버튼을 누르세요")
                        .font(.caption)
                    
                    Spacer()
                    
                    Button {
                        submitQuestion()
                    } label: {
                        if isAskingQuestion {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("질문하기")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(isAskingQuestion)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
            }
        }
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
        if editorMode == .question {
            if let originalDrawing = drawingBeforeQuestion {
                canvasView.drawing = originalDrawing
                noteStore.updateNote(id: note.id, drawing: originalDrawing)
            }
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
        let originalStrokes = Set(originalDrawing.strokes.map { $0.renderBounds })
        let questionStrokes = currentDrawing.strokes.filter { stroke in
            !originalStrokes.contains(stroke.renderBounds)
        }
        
        guard !questionStrokes.isEmpty else { return }
        
        var questionBounds = CGRect.null
        for stroke in questionStrokes {
            questionBounds = questionBounds.union(stroke.renderBounds)
        }
        
        let image = canvasView.drawing.image(from: canvasView.bounds, scale: 2.0)
        
        isAskingQuestion = true
        
        Task {
            do {
                let response = try await APIService.shared.askQuestion(
                    noteImage: image,
                    questionBounds: questionBounds,
                    strokeData: currentDrawing.dataRepresentation()
                )
                
                await MainActor.run {
                    questionAnswer = response.answer
                    showingAnswer = true
                    
                    canvasView.drawing = originalDrawing
                    noteStore.updateNote(id: note.id, drawing: originalDrawing)
                    editorMode = .drawing
                    isAskingQuestion = false
                }
            } catch {
                await MainActor.run {
                    questionAnswer = "오류: \(error.localizedDescription)"
                    showingAnswer = true
                    isAskingQuestion = false
                }
            }
        }
    }
    
    private func saveNote() {
        isSaving = true
        
        let image = canvasView.drawing.image(from: canvasView.bounds, scale: 2.0)
        
        Task {
            await noteStore.saveAndAnalyze(note: note, image: image)
            
            await MainActor.run {
                isSaving = false
                onDismiss()
            }
        }
    }
}

// MARK: - Note Canvas View
struct NoteCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    let initialDrawing: PKDrawing
    var onDrawingChanged: ((PKDrawing) -> Void)?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged)
    }
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = .white
        canvasView.overrideUserInterfaceStyle = .light
        canvasView.drawingPolicy = .pencilOnly
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvasView.drawing = initialDrawing
        canvasView.delegate = context.coordinator
        
        let toolPicker = PKToolPicker()
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
        context.coordinator.toolPicker = toolPicker
        
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var toolPicker: PKToolPicker?
        var onDrawingChanged: ((PKDrawing) -> Void)?
        
        init(onDrawingChanged: ((PKDrawing) -> Void)?) {
            self.onDrawingChanged = onDrawingChanged
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onDrawingChanged?(canvasView.drawing)
        }
    }
}

#Preview {
    NoteEditorView(note: Note()) {
        
    }
    .environmentObject(NoteStore())
}
