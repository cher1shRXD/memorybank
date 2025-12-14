// Views/Notes/PDFNoteEditorView.swift
import SwiftUI
import PencilKit
import PDFKit

struct PDFNoteEditorView: View {
    let noteId: UUID
    let pdfData: Data?
    let initialTitle: String?
    let onDismiss: () -> Void

    @EnvironmentObject var noteStore: NoteStore
    @State private var currentPage = 0
    @State private var totalPages = 0
    @State private var title: String = ""
    @State private var isEditingTitle = false
    @State private var isSaving = false
    @State private var pdfDocument: PDFDocument?

    init(noteId: UUID, pdfData: Data?, initialTitle: String? = nil, onDismiss: @escaping () -> Void) {
        self.noteId = noteId
        self.pdfData = pdfData
        self.initialTitle = initialTitle
        self.onDismiss = onDismiss
    }

    @State private var zoomableViewController: ZoomablePDFViewController?
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()

            // PDF canvas view
            if let pdfDocument = pdfDocument {
                ZoomablePDFCanvasView(
                    pdfDocument: pdfDocument,
                    noteId: noteId,
                    currentPage: $currentPage,
                    noteStore: noteStore,
                    viewController: $zoomableViewController
                )
                .onChange(of: currentPage) { _, _ in
                    totalPages = pdfDocument.pageCount
                }
            } else {
                ContentUnavailableView("PDF를 불러올 수 없습니다", systemImage: "doc.fill")
            }

            Divider()
            pageNavigationView
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            if let pdfData = pdfData {
                pdfDocument = PDFDocument(data: pdfData)
                totalPages = pdfDocument?.pageCount ?? 0
                title = initialTitle ?? "Untitled PDF"
            } else {
                // If no PDF data provided, close the editor
                onDismiss()
            }
        }
    }
    
    private func getZoomablePDFViewController() -> ZoomablePDFViewController? {
        return zoomableViewController
    }

    private var headerView: some View {
        HStack {
            Button("닫기") { 
                // Save before closing
                if let vc = getZoomablePDFViewController() {
                    Task {
                        let drawing = vc.getAllDrawings()
                        await noteStore.updateNote(id: noteId, drawing: drawing)
                        await MainActor.run {
                            onDismiss()
                        }
                    }
                } else {
                    onDismiss()
                }
            }
            Spacer()

            if isEditingTitle {
                TextField("제목", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                    .onSubmit {
                        // Title update not implemented yet
                        isEditingTitle = false
                    }
            } else {
                Button {
                    isEditingTitle = true
                } label: {
                    HStack(spacing: 4) {
                        Text(title).font(.headline)
                        Image(systemName: "pencil").font(.caption)
                    }
                    .foregroundStyle(.primary)
                }
            }

            Spacer()

            Button {
                isSaving = true
                // Save PDF drawings
                Task {
                    // For now, save the current page's drawing
                    // In the future, we should save all pages
                    if let vc = getZoomablePDFViewController() {
                        let drawing = vc.getCurrentDrawing()
                        await noteStore.updateNote(id: noteId, drawing: drawing)
                    }
                    await MainActor.run {
                        isSaving = false
                        onDismiss()
                    }
                }
            } label: {
                if isSaving { ProgressView() }
                else { Text("완료").fontWeight(.semibold) }
            }
            .disabled(isSaving)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var pageNavigationView: some View {
        HStack {
            Button {
                if currentPage > 0 { currentPage -= 1 }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title)
                    .foregroundStyle(currentPage > 0 ? .blue : .gray.opacity(0.3))
            }
            .disabled(currentPage == 0)

            Spacer()
            Text("\(currentPage + 1) / \(totalPages)")
                .font(.headline)
                .monospacedDigit()
            Spacer()

            Button {
                if currentPage < totalPages - 1 { currentPage += 1 }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title)
                    .foregroundStyle(currentPage < totalPages - 1 ? .blue : .gray.opacity(0.3))
            }
            .disabled(currentPage >= totalPages - 1)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Zoomable PDF Canvas View
struct ZoomablePDFCanvasView: UIViewControllerRepresentable {
    let pdfDocument: PDFDocument
    let noteId: UUID
    @Binding var currentPage: Int
    let noteStore: NoteStore
    @Binding var viewController: ZoomablePDFViewController?

    func makeUIViewController(context: Context) -> ZoomablePDFViewController {
        let vc = ZoomablePDFViewController(
            pdfDocument: pdfDocument,
            noteId: noteId,
            noteStore: noteStore
        )
        vc.pageChangeHandler = { page in
            DispatchQueue.main.async { currentPage = page }
        }
        DispatchQueue.main.async {
            viewController = vc
        }
        return vc
    }

    func updateUIViewController(_ vc: ZoomablePDFViewController, context: Context) {
        if vc.currentPage != currentPage {
            vc.goToPage(currentPage)
        }
    }
}

// MARK: - ViewController
class ZoomablePDFViewController: UIViewController, PKCanvasViewDelegate, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    private let pdfDocument: PDFDocument
    private let noteId: UUID
    private let noteStore: NoteStore

    // 스크롤 뷰 (줌/스크롤 담당)
    private var scrollView: UIScrollView!
    // 컨테이너 뷰 (PDF와 캔버스를 담는 뷰)
    private var containerView: UIView!
    // 캔버스 뷰 (필기 담당)
    private var canvasView: PKCanvasView!
    // PDF 뷰
    private var pdfView: PDFView!
    private var toolPicker: PKToolPicker!

    private(set) var currentPage: Int = 0
    var pageChangeHandler: ((Int) -> Void)?

    private var pageSize: CGSize = .zero
    private var isUpdatingDrawing = false
    private var pageDrawingCache: [Int: PKDrawing] = [:]
    private var hasInitializedLayout = false
    private var lastScale: CGFloat = 1.0

    init(pdfDocument: PDFDocument, noteId: UUID, noteStore: NoteStore) {
        self.pdfDocument = pdfDocument
        self.noteId = noteId
        self.noteStore = noteStore
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGray6
        setupViews()
        setupToolPicker()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if !hasInitializedLayout && view.bounds.size != .zero {
            hasInitializedLayout = true
            loadPage(currentPage)
        }
    }

    // MARK: - Setup
    private func setupViews() {
        // 스크롤 뷰 설정
        scrollView = UIScrollView()
        scrollView.delegate = self
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 5.0
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 컨테이너 뷰 설정
        containerView = UIView()
        containerView.backgroundColor = .clear
        scrollView.addSubview(containerView)
        
        // PDF 뷰 설정
        pdfView = PDFView()
        pdfView.document = pdfDocument
        pdfView.displayMode = .singlePage
        pdfView.autoScales = false
        pdfView.backgroundColor = .white
        pdfView.displayDirection = .horizontal
        pdfView.isUserInteractionEnabled = false
        containerView.addSubview(pdfView)
        
        // 캔버스 뷰 설정
        canvasView = PKCanvasView()
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .pencilOnly  // Apple Pencil 전용
        canvasView.delegate = self
        canvasView.isScrollEnabled = false
        canvasView.isUserInteractionEnabled = true
        containerView.addSubview(canvasView)
        
        // 핀치 제스처 추가
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchGesture.delegate = self
        scrollView.addGestureRecognizer(pinchGesture)
        
        // 더블 탭 제스처 추가 (빠른 확대/축소)
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
    }

    private func setupToolPicker() {
        // Create new tool picker instance
        self.toolPicker = PKToolPicker()
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        
        // 기본 펜 설정 (더 부드러운 필기를 위해)
        let defaultPen = PKInkingTool(.pen, color: .black, width: 2.0)
        // Set default pen (deprecated selectedTool, need to update to selectedToolItem)
        if #available(iOS 18.0, *) {
            // toolPicker.selectedToolItem = defaultPen // Need to update when API is available
        } else {
            toolPicker.selectedTool = defaultPen
        }
        
        canvasView.becomeFirstResponder()
        
        // 필기 성능 향상을 위한 설정
        canvasView.drawingGestureRecognizer.isEnabled = true
        canvasView.drawingGestureRecognizer.delaysTouchesBegan = false
        canvasView.drawingGestureRecognizer.delaysTouchesEnded = false
        canvasView.drawingGestureRecognizer.cancelsTouchesInView = false
    }

    // MARK: - Page Loading
    func loadPage(_ index: Int) {
        guard index >= 0, index < pdfDocument.pageCount,
              let page = pdfDocument.page(at: index) else { return }

        guard view.bounds.width > 0, view.bounds.height > 0 else {
            DispatchQueue.main.async { [weak self] in
                self?.loadPage(index)
            }
            return
        }

        // 현재 드로잉 저장
        if currentPage != index && !canvasView.drawing.strokes.isEmpty {
            saveCurrentDrawing()
        }

        currentPage = index
        
        // PDF 페이지 설정
        pdfView.go(to: page)
        
        // 페이지 크기 가져오기
        let bounds = page.bounds(for: .mediaBox)
        pageSize = bounds.size
        
        // 컨테이너 뷰 크기 설정
        containerView.frame = CGRect(origin: .zero, size: pageSize)
        scrollView.contentSize = pageSize
        
        // PDF 뷰와 캔버스 뷰 크기 설정
        pdfView.frame = CGRect(origin: .zero, size: pageSize)
        canvasView.frame = CGRect(origin: .zero, size: pageSize)
        
        // 초기 줌 스케일 계산
        let widthScale = scrollView.bounds.width / pageSize.width
        let heightScale = scrollView.bounds.height / pageSize.height
        let fitScale = min(widthScale, heightScale) * 0.95
        
        scrollView.minimumZoomScale = fitScale * 0.5
        scrollView.maximumZoomScale = fitScale * 5.0
        
        // 페이지 이동 시 줌 스케일과 오프셋 초기화
        scrollView.setZoomScale(fitScale, animated: false)
        scrollView.contentOffset = CGPoint.zero
        lastScale = fitScale
        
        // 중앙 정렬
        centerContent()
        
        // 드로잉 로드
        loadDrawing(for: index)
    }

    func goToPage(_ index: Int) {
        guard index != currentPage else { return }
        loadPage(index)
        pageChangeHandler?(index)
    }

    // MARK: - Drawing Management
    private func loadDrawing(for page: Int) {
        isUpdatingDrawing = true

        if let cached = pageDrawingCache[page] {
            canvasView.drawing = cached
        } else if noteStore.getNote(id: noteId) != nil {
            // Multi-page PDF not implemented yet
            let drawing = PKDrawing()
            canvasView.drawing = drawing
            pageDrawingCache[page] = drawing
        } else {
            canvasView.drawing = PKDrawing()
        }

        isUpdatingDrawing = false
    }

    private func saveCurrentDrawing() {
        guard !isUpdatingDrawing else { return }
        let drawing = canvasView.drawing
        pageDrawingCache[currentPage] = drawing
        // Multi-page update not implemented yet
        // noteStore.updatePageDrawing(id: noteId, page: currentPage, drawing: drawing)
    }

    // MARK: - Layout
    private func centerContent() {
        let offsetX = max(0, (scrollView.bounds.width - scrollView.contentSize.width * scrollView.zoomScale) / 2)
        let offsetY = max(0, (scrollView.bounds.height - scrollView.contentSize.height * scrollView.zoomScale) / 2)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
    }

    // MARK: - PKCanvasViewDelegate
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard !isUpdatingDrawing else { return }
        pageDrawingCache[currentPage] = canvasView.drawing
        
        // Auto-save after 2 seconds of no changes
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(autoSave), object: nil)
        perform(#selector(autoSave), with: nil, afterDelay: 2.0)
    }
    
    @objc private func autoSave() {
        Task {
            // For now, save all drawings combined
            let allDrawings = getAllDrawings()
            await noteStore.updateNote(id: noteId, drawing: allDrawings)
        }
    }

    // MARK: - UIScrollViewDelegate
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return containerView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerContent()
        
        // 줌 스케일에 따라 펜 굵기 조정
        let scale = scrollView.zoomScale / lastScale
        // Handle tool adjustment (deprecated selectedTool)
        if let tool = toolPicker.selectedTool as? PKInkingTool {
            let newWidth = tool.width / scale
            let newTool = PKInkingTool(tool.inkType, color: tool.color, width: newWidth)
            toolPicker.selectedTool = newTool
        }
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        lastScale = scale
    }
    
    // MARK: - Gesture Handlers
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began || gesture.state == .changed {
            let currentScale = scrollView.zoomScale
            let newScale = currentScale * gesture.scale
            
            // 스케일 제한
            let finalScale = max(scrollView.minimumZoomScale, min(newScale, scrollView.maximumZoomScale))
            scrollView.zoomScale = finalScale
            
            gesture.scale = 1.0
        }
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: containerView)
        
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            // 축소
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            // 확대 (탭한 지점을 중심으로)
            let zoomScale = min(scrollView.zoomScale * 2.5, scrollView.maximumZoomScale)
            let rect = zoomRectForScale(zoomScale, center: point)
            scrollView.zoom(to: rect, animated: true)
        }
    }
    
    private func zoomRectForScale(_ scale: CGFloat, center: CGPoint) -> CGRect {
        var zoomRect = CGRect.zero
        zoomRect.size.width = scrollView.frame.size.width / scale
        zoomRect.size.height = scrollView.frame.size.height / scale
        zoomRect.origin.x = center.x - (zoomRect.size.width / 2.0)
        zoomRect.origin.y = center.y - (zoomRect.size.height / 2.0)
        return zoomRect
    }
    
    // MARK: - UIGestureRecognizerDelegate
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    // MARK: - Public Methods
    func getCurrentDrawing() -> PKDrawing {
        // Save current page's drawing
        saveCurrentDrawing()
        
        // For now, return only the current page's drawing
        // In the future, we should combine all pages' drawings
        return canvasView.drawing
    }
    
    func getAllDrawings() -> PKDrawing {
        // Save current page first
        saveCurrentDrawing()
        
        // Combine all drawings from all pages
        var combinedDrawing = PKDrawing()
        // This is a simplified version - in reality, we'd need to position
        // each page's drawing appropriately
        for (_, drawing) in pageDrawingCache {
            for stroke in drawing.strokes {
                combinedDrawing.strokes.append(stroke)
            }
        }
        return combinedDrawing
    }
    
    // MARK: - Cleanup
    deinit {
        saveCurrentDrawing()
        // Save is now handled via API
    }
}

