// Views/Notes/NoteEditorView.swift
import SwiftUI
import PencilKit

enum EditorMode {
    case drawing
    case question
}

struct NoteEditorView: View {
    let noteId: UUID
    let initialDrawing: PKDrawing?
    let onDismiss: () -> Void
    
    @EnvironmentObject var noteStore: NoteStore
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker: PKToolPicker?
    @State private var editorMode: EditorMode = .drawing
    @State private var isSaving = false
    @State private var showingTitleAlert = false
    @State private var titleText = ""
    @State private var currentDrawing = PKDrawing()
    @State private var note: NoteResponse?
    @State private var lastSavedDrawing = PKDrawing()
    @State private var saveWorkItem: DispatchWorkItem?
    
    // 질문 모드용
    @State private var drawingBeforeQuestion: PKDrawing?
    @State private var questionAnswer: String?
    @State private var showingAnswer = false
    @State private var isAskingQuestion = false
    
    init(noteId: UUID, initialDrawing: PKDrawing? = nil, onDismiss: @escaping () -> Void) {
        self.noteId = noteId
        self.initialDrawing = initialDrawing
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 캔버스 뷰
                CanvasViewRepresentable(
                        canvasView: $canvasView,
                        toolPicker: $toolPicker,
                        initialDrawing: currentDrawing,
                        onDrawingChanged: { drawing in
                            print("[NoteEditorView] Drawing changed: \(drawing.strokes.count) strokes")
                            currentDrawing = drawing
                            if editorMode == .drawing {
                                print("[NoteEditorView] In drawing mode, setting auto-save")
                                
                                // Cancel previous work item
                                saveWorkItem?.cancel()
                                
                                // Create new work item
                                let workItem = DispatchWorkItem {
                                    print("[NoteEditorView] Auto-save work item executing")
                                    Task { @MainActor in
                                        print("[NoteEditorView] Auto-saving drawing with \(drawing.strokes.count) strokes")
                                        await noteStore.updateNote(id: noteId, drawing: drawing)
                                        lastSavedDrawing = drawing
                                    }
                                }
                                saveWorkItem = workItem
                                
                                // Schedule for 2 seconds later
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
                            }
                        }
                    )
                    .background(Color.white)
                
                // 하단 모드 토글
                modeToggleView
                    .background(Color(.systemBackground))
            }
            .background(Color(.systemBackground))
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        print("[NoteEditorView] Cancel button pressed")
                        // Save before closing
                        saveWorkItem?.cancel()
                        Task {
                            print("[NoteEditorView] Saving on cancel")
                            await noteStore.updateNote(id: noteId, drawing: currentDrawing)
                            await MainActor.run {
                                onDismiss()
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveNote()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("완료")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .principal) {
                    Button {
                        showingTitleAlert = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(titleText)
                                .font(.headline)
                            Image(systemName: "pencil.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .alert("제목 변경", isPresented: $showingTitleAlert) {
                TextField("제목", text: $titleText)
                Button("취소", role: .cancel) {}
                Button("확인") {
                    // Title update would go here
                }
            }
        }
        .sheet(isPresented: $showingAnswer) {
            answerSheet
        }
        .onDisappear {
            print("[NoteEditorView] View disappearing, saving...")
            // Clean up and save when view disappears
            saveWorkItem?.cancel()
            // Only save if drawing has changed (check stroke count as simple comparison)
            if currentDrawing.strokes.count != lastSavedDrawing.strokes.count {
                Task {
                    print("[NoteEditorView] Saving on disappear with \(currentDrawing.strokes.count) strokes")
                    await noteStore.updateNote(id: noteId, drawing: currentDrawing)
                }
            }
        }
        .task {
            print("[NoteEditorView] Loading note with ID: \(noteId)")
            print("[NoteEditorView] Initial drawing provided: \(initialDrawing != nil)")
            
            // Use initial drawing if provided (for newly created notes)
            if let initialDrawing = initialDrawing {
                print("[NoteEditorView] Using initial drawing")
                self.currentDrawing = initialDrawing
                self.titleText = "Untitled"
            } else {
                print("[NoteEditorView] Loading from API...")
                // Load note data from API
                do {
                    let noteResponse = try await APIService.shared.getNote(id: noteId)
                    print("[NoteEditorView] Loaded note from API: \(noteResponse.id)")
                    self.note = noteResponse
                    self.titleText = noteResponse.description ?? "Untitled"
                    
                    // Load drawing if available
                    if let drawingDataString = noteResponse.drawing_data,
                       let drawingData = Data(base64Encoded: drawingDataString),
                       let drawing = try? PKDrawing(data: drawingData) {
                        self.currentDrawing = drawing
                        print("[NoteEditorView] Loaded drawing from API")
                    }
                } catch {
                    print("[NoteEditorView] Error loading note: \(error)")
                    // If loading fails and no initial drawing, close the editor
                    if initialDrawing == nil {
                        print("[NoteEditorView] Closing editor due to load failure")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onDismiss()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Mode Toggle
    private var modeToggleView: some View {
        HStack {
            Button {
                switchToDrawingMode()
            } label: {
                Label("그리기", systemImage: "pencil.tip")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(editorMode == .drawing ? Color.blue : Color.clear)
                    .foregroundColor(editorMode == .drawing ? .white : .primary)
            }
            
            Divider()
                .frame(height: 40)
            
            Button {
                switchToQuestionMode()
            } label: {
                Label("질문하기", systemImage: "questionmark.circle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(editorMode == .question ? Color.orange : Color.clear)
                    .foregroundColor(editorMode == .question ? .white : .primary)
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding()
    }
    
    // MARK: - Answer Sheet
    private var answerSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("AI 답변")
                    .font(.title)
                    .fontWeight(.bold)
                
                ScrollView {
                    Text(questionAnswer ?? "")
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
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
                currentDrawing = originalDrawing
                Task {
                    await noteStore.updateNote(id: noteId, drawing: originalDrawing)
                }
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
                let response = try await APIService.shared.chatWithHandwriting(
                    noteId: noteId,
                    canvasImage: image,
                    questionBounds: questionBounds
                )
                
                await MainActor.run {
                    questionAnswer = response.answer
                    showingAnswer = true
                    
                    canvasView.drawing = originalDrawing
                    self.currentDrawing = originalDrawing
                    Task {
                        await noteStore.updateNote(id: noteId, drawing: originalDrawing)
                    }
                    editorMode = .drawing
                    isAskingQuestion = false
                }
            } catch {
                await MainActor.run {
                    isAskingQuestion = false
                    // 에러 처리
                }
            }
        }
    }
    
    private func saveNote() {
        print("[NoteEditorView] saveNote called")
        isSaving = true
        saveWorkItem?.cancel()

        Task {
            print("[NoteEditorView] Saving with complete button")
            // Save through noteStore to maintain consistency
            await noteStore.updateNote(id: noteId, drawing: currentDrawing)

            await MainActor.run {
                isSaving = false
                onDismiss()
            }
        }
    }
}

// MARK: - Canvas View Representable
struct CanvasViewRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var toolPicker: PKToolPicker?
    let initialDrawing: PKDrawing
    var onDrawingChanged: ((PKDrawing) -> Void)?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged)
    }
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = .white
        canvasView.overrideUserInterfaceStyle = .light
        canvasView.drawingPolicy = .anyInput  // 모든 입력 허용
        canvasView.drawing = initialDrawing
        canvasView.delegate = context.coordinator
        
        // 툴 피커 설정
        let picker = PKToolPicker()
        picker.setVisible(true, forFirstResponder: canvasView)
        picker.addObserver(canvasView)
        toolPicker = picker
        canvasView.becomeFirstResponder()
        
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // 필요시 업데이트
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var onDrawingChanged: ((PKDrawing) -> Void)?
        
        init(onDrawingChanged: ((PKDrawing) -> Void)?) {
            self.onDrawingChanged = onDrawingChanged
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            print("[Coordinator] canvasViewDrawingDidChange called: \(canvasView.drawing.strokes.count) strokes")
            onDrawingChanged?(canvasView.drawing)
        }
    }
}

#Preview {
    NoteEditorView(noteId: UUID(), initialDrawing: PKDrawing()) {
        
    }
    .environmentObject(NoteStore())
}