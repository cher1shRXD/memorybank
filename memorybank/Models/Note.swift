import Foundation
import PencilKit

struct Note: Identifiable, Codable {
    let id: UUID
    var title: String
    var drawingData: Data
    var pageDrawings: [Int: Data]  // PDF 페이지별 필기
    var pdfData: Data?
    var createdAt: Date
    var updatedAt: Date
    
    // AI 분석 결과
    var description: String?
    var conceptIds: [UUID]
    
    var drawing: PKDrawing {
        get {
            (try? PKDrawing(data: drawingData)) ?? PKDrawing()
        }
        set {
            drawingData = (try? newValue.dataRepresentation()) ?? Data()
        }
    }
    
    func getPageDrawing(page: Int) -> PKDrawing {
        guard let data = pageDrawings[page] else { return PKDrawing() }
        return (try? PKDrawing(data: data)) ?? PKDrawing()
    }
    
    mutating func setPageDrawing(page: Int, drawing: PKDrawing) {
        pageDrawings[page] = (try? drawing.dataRepresentation()) ?? Data()
    }
    
    var hasPDF: Bool {
        pdfData != nil
    }
    
    init(
        id: UUID = UUID(),
        title: String = "새 노트",
        drawing: PKDrawing = PKDrawing(),
        pdfData: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.drawingData = (try? drawing.dataRepresentation()) ?? Data()
        self.pageDrawings = [:]
        self.pdfData = pdfData
        self.createdAt = Date()
        self.updatedAt = Date()
        self.description = nil
        self.conceptIds = []
    }
}
