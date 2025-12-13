// ViewModels/GraphViewModel.swift
import SwiftUI
import Combine

// 그래프 표시용 노드
struct GraphDisplayNode: Identifiable {
    let id: String
    let label: String
    let type: String // "Concept" or "Note"
    var position: CGPoint = .zero
    var velocity: CGPoint = .zero
}

// 그래프 표시용 엣지
struct GraphDisplayEdge: Identifiable {
    var id: String { "\(sourceId)-\(targetId)" }
    let sourceId: String
    let targetId: String
    let type: String
}

class GraphViewModel: ObservableObject {
    @Published var nodes: [GraphDisplayNode] = []
    @Published var edges: [GraphDisplayEdge] = []
    @Published var selectedNode: GraphDisplayNode?
    @Published var scale: CGFloat = 1.0
    @Published var offset: CGSize = .zero
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIService.shared
    private var simulationTimer: Timer?
    private var isSimulating = false

    // Force-directed layout 파라미터
    private let repulsionStrength: CGFloat = 5000
    private let attractionStrength: CGFloat = 0.01
    private let centerStrength: CGFloat = 0.005
    private let damping: CGFloat = 0.9
    private let minDistance: CGFloat = 100

    init() {}

    // MARK: - Data Loading
    func fetchGraph() async {
        await MainActor.run { isLoading = true }

        do {
            let response = try await api.getGraph()

            await MainActor.run {
                nodes = response.nodes.map { node in
                    GraphDisplayNode(
                        id: node.id,
                        label: node.name,
                        type: node.type
                    )
                }

                edges = response.edges.map { edge in
                    GraphDisplayEdge(
                        sourceId: edge.source,
                        targetId: edge.target,
                        type: edge.type
                    )
                }

                initializePositions()
                startSimulation()
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func fetchConceptGraph(name: String) async {
        await MainActor.run { isLoading = true }

        do {
            let response = try await api.getConceptGraph(name: name)

            await MainActor.run {
                // Clear existing nodes and edges
                nodes = []
                edges = []
                
                // Add center node
                let centerNode = GraphDisplayNode(
                    id: "center-\(response.center.name)",
                    label: response.center.name,
                    type: "Concept"
                )
                nodes.append(centerNode)
                
                // Add connected concepts
                for (index, connected) in response.connected.enumerated() {
                    let nodeId = "concept-\(index)-\(connected.concept)"
                    let node = GraphDisplayNode(
                        id: nodeId,
                        label: connected.concept,
                        type: "Concept"
                    )
                    nodes.append(node)
                    
                    // Add edge
                    let edge = GraphDisplayEdge(
                        sourceId: centerNode.id,
                        targetId: nodeId,
                        type: connected.relation
                    )
                    edges.append(edge)
                }

                initializePositions()
                startSimulation()
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    // MARK: - Position Initialization
    func initializePositions(in size: CGSize = CGSize(width: 400, height: 600)) {
        let centerX = size.width / 2
        let centerY = size.height / 2

        for i in 0..<nodes.count {
            let angle = (CGFloat(i) / CGFloat(max(nodes.count, 1))) * 2 * .pi
            let radius: CGFloat = 150
            nodes[i].position = CGPoint(
                x: centerX + cos(angle) * radius + CGFloat.random(in: -20...20),
                y: centerY + sin(angle) * radius + CGFloat.random(in: -20...20)
            )
            nodes[i].velocity = .zero
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
        guard nodes.count > 1 else { return }

        var forces = [String: CGPoint]()

        for node in nodes {
            forces[node.id] = .zero
        }

        // Repulsion forces
        for i in 0..<nodes.count {
            for j in (i+1)..<nodes.count {
                let dx = nodes[j].position.x - nodes[i].position.x
                let dy = nodes[j].position.y - nodes[i].position.y
                let distance = max(sqrt(dx * dx + dy * dy), 1)

                let force = repulsionStrength / (distance * distance)
                let fx = (dx / distance) * force
                let fy = (dy / distance) * force

                forces[nodes[i].id]?.x -= fx
                forces[nodes[i].id]?.y -= fy
                forces[nodes[j].id]?.x += fx
                forces[nodes[j].id]?.y += fy
            }
        }

        // Attraction forces
        for edge in edges {
            guard let sourceIndex = nodes.firstIndex(where: { $0.id == edge.sourceId }),
                  let targetIndex = nodes.firstIndex(where: { $0.id == edge.targetId }) else {
                continue
            }

            let dx = nodes[targetIndex].position.x - nodes[sourceIndex].position.x
            let dy = nodes[targetIndex].position.y - nodes[sourceIndex].position.y
            let distance = sqrt(dx * dx + dy * dy)

            let targetDistance = minDistance * 1.5
            let force = (distance - targetDistance) * attractionStrength
            let fx = (dx / max(distance, 1)) * force
            let fy = (dy / max(distance, 1)) * force

            forces[nodes[sourceIndex].id]?.x += fx
            forces[nodes[sourceIndex].id]?.y += fy
            forces[nodes[targetIndex].id]?.x -= fx
            forces[nodes[targetIndex].id]?.y -= fy
        }

        // Center gravity
        let centerX: CGFloat = 200
        let centerY: CGFloat = 300

        for i in 0..<nodes.count {
            let dx = centerX - nodes[i].position.x
            let dy = centerY - nodes[i].position.y

            forces[nodes[i].id]?.x += dx * centerStrength
            forces[nodes[i].id]?.y += dy * centerStrength
        }

        // Apply forces
        var totalMovement: CGFloat = 0

        for i in 0..<nodes.count {
            guard let force = forces[nodes[i].id] else { continue }

            nodes[i].velocity.x = (nodes[i].velocity.x + force.x) * damping
            nodes[i].velocity.y = (nodes[i].velocity.y + force.y) * damping

            nodes[i].position.x += nodes[i].velocity.x
            nodes[i].position.y += nodes[i].velocity.y

            totalMovement += abs(nodes[i].velocity.x) + abs(nodes[i].velocity.y)
        }

        if totalMovement < 0.1 {
            stopSimulation()
        }
    }

    // MARK: - Interactions
    func selectNode(_ node: GraphDisplayNode?) {
        selectedNode = node
    }

    func focusOnNode(_ node: GraphDisplayNode) {
        selectedNode = node

        if node.type == "Concept" {
            Task {
                await fetchConceptGraph(name: node.label)
            }
        }

        withAnimation(.spring(response: 0.5)) {
            scale = 1.5
            offset = CGSize(
                width: 200 - node.position.x,
                height: 300 - node.position.y
            )
        }
    }

    func resetView() {
        selectedNode = nil

        withAnimation(.spring(response: 0.5)) {
            scale = 1.0
            offset = .zero
        }

        Task {
            await fetchGraph()
        }
    }

    // 개념 노드만 필터링
    var conceptNodes: [GraphDisplayNode] {
        nodes.filter { $0.type == "Concept" }
    }

    // 노트 노드만 필터링
    var noteNodes: [GraphDisplayNode] {
        nodes.filter { $0.type == "Note" }
    }
}
