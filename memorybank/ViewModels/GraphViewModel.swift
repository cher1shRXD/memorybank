// ViewModels/GraphViewModel.swift
import SwiftUI
import Combine

class GraphViewModel: ObservableObject {
    @Published var concepts: [Concept] = []
    @Published var relations: [Relation] = []
    @Published var selectedConcept: Concept?
    @Published var scale: CGFloat = 1.0
    @Published var offset: CGSize = .zero
    @Published var isLoading = false
    
    private let storage = StorageService.shared
    private let api = APIService.shared
    private var simulationTimer: Timer?
    private var isSimulating = false
    
    // Force-directed layout 파라미터
    private let repulsionStrength: CGFloat = 5000
    private let attractionStrength: CGFloat = 0.01
    private let centerStrength: CGFloat = 0.005
    private let damping: CGFloat = 0.9
    private let minDistance: CGFloat = 100
    
    init() {
        loadLocalData()
    }
    
    // MARK: - Data Loading
    func loadLocalData() {
        concepts = storage.loadConcepts()
        relations = storage.loadRelations()
        initializePositions()
    }
    
    func fetchGraphFromServer() async {
        await MainActor.run { isLoading = true }
        
        do {
            let response = try await api.getUserGraph(depth: 2, limit: 100)
            
            await MainActor.run {
                // 노드를 Concept으로 변환
                concepts = response.nodes
                    .filter { $0.type == "concept" }
                    .map { node in
                        Concept(
                            id: UUID(uuidString: node.id) ?? UUID(),
                            name: node.label,
                            description: nil
                        )
                    }
                
                // 엣지를 Relation으로 변환
                relations = response.edges.compactMap { edge in
                    guard let sourceId = UUID(uuidString: edge.source),
                          let targetId = UUID(uuidString: edge.target),
                          let type = RelationType(rawValue: edge.type) else {
                        return nil
                    }
                    return Relation(
                        sourceId: sourceId,
                        targetId: targetId,
                        type: type,
                        strength: edge.weight ?? 1.0
                    )
                }
                
                saveLocal()
                initializePositions()
                startSimulation()
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    func fetchConceptGraph(name: String) async {
        await MainActor.run { isLoading = true }
        
        do {
            let response = try await api.getConceptGraph(name: name, depth: 2)
            
            await MainActor.run {
                concepts = response.nodes
                    .filter { $0.type == "concept" }
                    .map { node in
                        Concept(
                            id: UUID(uuidString: node.id) ?? UUID(),
                            name: node.label,
                            description: nil
                        )
                    }
                
                relations = response.edges.compactMap { edge in
                    guard let sourceId = UUID(uuidString: edge.source),
                          let targetId = UUID(uuidString: edge.target),
                          let type = RelationType(rawValue: edge.type) else {
                        return nil
                    }
                    return Relation(
                        sourceId: sourceId,
                        targetId: targetId,
                        type: type,
                        strength: edge.weight ?? 1.0
                    )
                }
                
                initializePositions()
                startSimulation()
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    // MARK: - Position Initialization
    func initializePositions(in size: CGSize = CGSize(width: 400, height: 600)) {
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        for i in 0..<concepts.count {
            let angle = (CGFloat(i) / CGFloat(concepts.count)) * 2 * .pi
            let radius: CGFloat = 150
            concepts[i].position = CGPoint(
                x: centerX + cos(angle) * radius + CGFloat.random(in: -20...20),
                y: centerY + sin(angle) * radius + CGFloat.random(in: -20...20)
            )
            concepts[i].velocity = .zero
        }
    }
    
    // MARK: - Force-directed Simulation
    func startSimulation() {
        guard !isSimulating else { return }
        isSimulating = true
        
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in
            self?.simulationStep()
        }
    }
    
    func stopSimulation() {
        isSimulating = false
        simulationTimer?.invalidate()
        simulationTimer = nil
    }
    
    private func simulationStep() {
        guard concepts.count > 1 else { return }
        
        var forces = [UUID: CGPoint]()
        
        for concept in concepts {
            forces[concept.id] = .zero
        }
        
        // Repulsion forces
        for i in 0..<concepts.count {
            for j in (i+1)..<concepts.count {
                let dx = concepts[j].position.x - concepts[i].position.x
                let dy = concepts[j].position.y - concepts[i].position.y
                let distance = max(sqrt(dx * dx + dy * dy), 1)
                
                let force = repulsionStrength / (distance * distance)
                let fx = (dx / distance) * force
                let fy = (dy / distance) * force
                
                forces[concepts[i].id]?.x -= fx
                forces[concepts[i].id]?.y -= fy
                forces[concepts[j].id]?.x += fx
                forces[concepts[j].id]?.y += fy
            }
        }
        
        // Attraction forces
        for relation in relations {
            guard let sourceIndex = concepts.firstIndex(where: { $0.id == relation.sourceId }),
                  let targetIndex = concepts.firstIndex(where: { $0.id == relation.targetId }) else {
                continue
            }
            
            let dx = concepts[targetIndex].position.x - concepts[sourceIndex].position.x
            let dy = concepts[targetIndex].position.y - concepts[sourceIndex].position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            let targetDistance = minDistance * 1.5
            let force = (distance - targetDistance) * attractionStrength
            let fx = (dx / max(distance, 1)) * force
            let fy = (dy / max(distance, 1)) * force
            
            forces[concepts[sourceIndex].id]?.x += fx
            forces[concepts[sourceIndex].id]?.y += fy
            forces[concepts[targetIndex].id]?.x -= fx
            forces[concepts[targetIndex].id]?.y -= fy
        }
        
        // Center gravity
        let centerX: CGFloat = 200
        let centerY: CGFloat = 300
        
        for i in 0..<concepts.count {
            let dx = centerX - concepts[i].position.x
            let dy = centerY - concepts[i].position.y
            
            forces[concepts[i].id]?.x += dx * centerStrength
            forces[concepts[i].id]?.y += dy * centerStrength
        }
        
        // Apply forces
        var totalMovement: CGFloat = 0
        
        for i in 0..<concepts.count {
            guard let force = forces[concepts[i].id] else { continue }
            
            concepts[i].velocity.x = (concepts[i].velocity.x + force.x) * damping
            concepts[i].velocity.y = (concepts[i].velocity.y + force.y) * damping
            
            concepts[i].position.x += concepts[i].velocity.x
            concepts[i].position.y += concepts[i].velocity.y
            
            totalMovement += abs(concepts[i].velocity.x) + abs(concepts[i].velocity.y)
        }
        
        if totalMovement < 0.1 {
            stopSimulation()
        }
    }
    
    // MARK: - Interactions
    func selectConcept(_ concept: Concept?) {
        selectedConcept = concept
    }
    
    func focusOnConcept(_ concept: Concept) {
        selectedConcept = concept
        
        // 해당 개념 중심 그래프 가져오기
        Task {
            await fetchConceptGraph(name: concept.name)
        }
        
        withAnimation(.spring(response: 0.5)) {
            scale = 1.5
            offset = CGSize(
                width: 200 - concept.position.x,
                height: 300 - concept.position.y
            )
        }
    }
    
    func resetView() {
        withAnimation(.spring(response: 0.5)) {
            scale = 1.0
            offset = .zero
        }
        
        // 전체 그래프 다시 가져오기
        Task {
            await fetchGraphFromServer()
        }
    }
    
    func getRelatedNotes(for concept: Concept, in noteStore: NoteStore) -> [Note] {
        noteStore.notes.filter { $0.conceptIds.contains(concept.id) }
    }
    
    // MARK: - Persistence
    private func saveLocal() {
        storage.saveConcepts(concepts)
        storage.saveRelations(relations)
    }
}
