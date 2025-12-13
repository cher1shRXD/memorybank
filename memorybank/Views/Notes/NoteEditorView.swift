// Views/Notes/NoteEditorView.swift
import SwiftUI
import PencilKit

enum EditorMode {
    case drawing
    case question
}

struct NoteEditorView: View {
    let noteId: UUID
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
    
    // 질문 모드용
    @State private var drawingBeforeQuestion: PKDrawing?
    @State private var questionAnswer: String?
    @State private var showingAnswer = false
    @State private var isAskingQuestion = false
    
    init(noteId: UUID, onDismiss: @escaping () -> Void) {
        self.noteId = noteId
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 캔버스 뷰
                CanvasViewRepresentable(
                    canvasView: $canvasView,
                    toolPicker: $toolPicker,
                    initialDrawing: currentDrawing,
                    onDrawingChanged: { drawing in
                        currentDrawing = drawing
                        if editorMode == .drawing {
                            Task {
                                // Update drawing via API
                                let drawingData = drawing.dataRepresentation().base64EncodedString()
                                _ = try? await APIService.shared.updateNote(
                                    id: noteId,
                                    drawingData: drawingData
                                )
                            }
                        }
                    }
                )
                .background(Color.white)
                
                // 하단 모드 토글
                modeToggleView
                    .background(Color(.systemBackground))
            }
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        onDismiss()
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
        .task {
            // Load note data
            do {
                let noteResponse = try await APIService.shared.getNote(id: noteId)
                self.note = noteResponse
                self.titleText = noteResponse.description ?? "Untitled"
                
                // Load drawing if available
                if let drawingDataString = noteResponse.drawing_data,
                   let drawingData = Data(base64Encoded: drawingDataString),
                   let drawing = try? PKDrawing(data: drawingData) {
                    self.currentDrawing = drawing
                }
            } catch {
                print("Error loading note: \(error)")
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
                    let drawingData = originalDrawing.dataRepresentation().base64EncodedString()
                    _ = try? await APIService.shared.updateNote(
                        id: noteId,
                        drawingData: drawingData
                    )
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
                        let drawingData = originalDrawing.dataRepresentation().base64EncodedString()
                        _ = try? await APIService.shared.updateNote(
                            id: noteId,
                            drawingData: drawingData
                        )
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
        isSaving = true

        Task {
            // 서버에 저장
            let drawingData = currentDrawing.dataRepresentation().base64EncodedString()
            let thumbnail = currentDrawing.image(from: currentDrawing.bounds, scale: UIScreen.main.scale)
            
            _ = try? await APIService.shared.updateNote(
                id: noteId,
                drawingData: drawingData,
                thumbnail: thumbnail
            )

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
            onDrawingChanged?(canvasView.drawing)
        }
    }
}

#Preview {
    NoteEditorView(noteId: UUID()) {
        
    }
    .environmentObject(NoteStore())
}