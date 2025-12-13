// Views/Graph/GraphView.swift
import SwiftUI

struct GraphView: View {
    @EnvironmentObject var graphViewModel: GraphViewModel
    @EnvironmentObject var noteStore: NoteStore

    @GestureState private var magnification: CGFloat = 1.0

    // 드래그용 State
    @State private var currentDragOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                // 배경
                Color(.systemBackground)
                    .ignoresSafeArea()

                // 그래프 캔버스
                graphCanvas
                    .scaleEffect(graphViewModel.scale * magnification)
                    .offset(
                        x: graphViewModel.offset.width + currentDragOffset.width,
                        y: graphViewModel.offset.height + currentDragOffset.height
                    )
                    .gesture(dragGesture)
                    .gesture(magnificationGesture)

                // 선택된 노드 정보
                VStack {
                    Spacer()

                    if let node = graphViewModel.selectedNode {
                        selectedNodePanel(node: node)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3), value: graphViewModel.selectedNode?.id)
            }
            .navigationTitle("지식 그래프")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        graphViewModel.resetView()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
            }
            .onAppear {
                Task {
                    await graphViewModel.fetchGraph()
                }
            }
            .onDisappear {
                graphViewModel.stopSimulation()
            }
        }
    }
    
    // MARK: - Graph Canvas
    private var graphCanvas: some View {
        Canvas { context, size in
            let centerOffset = CGPoint(x: size.width / 2, y: size.height / 2)

            // 엣지 그리기
            for edge in graphViewModel.edges {
                guard let source = graphViewModel.nodes.first(where: { $0.id == edge.sourceId }),
                      let target = graphViewModel.nodes.first(where: { $0.id == edge.targetId }) else {
                    continue
                }

                let sourcePoint = CGPoint(
                    x: source.position.x + centerOffset.x - 200,
                    y: source.position.y + centerOffset.y - 300
                )
                let targetPoint = CGPoint(
                    x: target.position.x + centerOffset.x - 200,
                    y: target.position.y + centerOffset.y - 300
                )

                var path = Path()
                path.move(to: sourcePoint)
                path.addLine(to: targetPoint)

                let edgeColor = colorForEdgeType(edge.type)
                let strokeStyle = StrokeStyle(lineWidth: 2)

                context.stroke(path, with: .color(edgeColor), style: strokeStyle)

                // 화살표 그리기 (REQUIRES, LEADS_TO 타입)
                if edge.type == "REQUIRES" || edge.type == "LEADS_TO" {
                    let angle = atan2(targetPoint.y - sourcePoint.y, targetPoint.x - sourcePoint.x)
                    let arrowLength: CGFloat = 10
                    let arrowAngle: CGFloat = .pi / 6

                    let arrowPoint = CGPoint(
                        x: targetPoint.x - 25 * cos(angle),
                        y: targetPoint.y - 25 * sin(angle)
                    )

                    var arrowPath = Path()
                    arrowPath.move(to: arrowPoint)
                    arrowPath.addLine(to: CGPoint(
                        x: arrowPoint.x - arrowLength * cos(angle - arrowAngle),
                        y: arrowPoint.y - arrowLength * sin(angle - arrowAngle)
                    ))
                    arrowPath.move(to: arrowPoint)
                    arrowPath.addLine(to: CGPoint(
                        x: arrowPoint.x - arrowLength * cos(angle + arrowAngle),
                        y: arrowPoint.y - arrowLength * sin(angle + arrowAngle)
                    ))

                    context.stroke(arrowPath, with: .color(edgeColor), style: StrokeStyle(lineWidth: 2))
                }
            }
        }
        .overlay {
            // 노드 그리기 (SwiftUI Views)
            GeometryReader { geometry in
                let centerOffset = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

                ForEach(graphViewModel.nodes) { node in
                    GraphNodeView(
                        node: node,
                        isSelected: graphViewModel.selectedNode?.id == node.id
                    )
                    .position(
                        x: node.position.x + centerOffset.x - 200,
                        y: node.position.y + centerOffset.y - 300
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            if graphViewModel.selectedNode?.id == node.id {
                                graphViewModel.selectNode(nil)
                            } else {
                                graphViewModel.selectNode(node)
                            }
                        }
                    }
                    .onLongPressGesture {
                        graphViewModel.focusOnNode(node)
                    }
                }
            }
        }
    }

    // 엣지 타입에 따른 색상
    private func colorForEdgeType(_ type: String) -> Color {
        switch type {
        case "REQUIRES": return .red
        case "CONTAINS": return .blue
        case "LEADS_TO": return .green
        default: return .gray
        }
    }
    
    // MARK: - Gestures
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .updating($magnification) { value, state, _ in
                state = value
            }
            .onEnded { value in
                graphViewModel.scale *= value
                graphViewModel.scale = min(max(graphViewModel.scale, 0.5), 3.0)
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                currentDragOffset = value.translation
            }
            .onEnded { value in
                graphViewModel.offset.width += value.translation.width
                graphViewModel.offset.height += value.translation.height
                currentDragOffset = .zero
            }
    }
    
    // MARK: - Selected Node Panel
    private func selectedNodePanel(node: GraphDisplayNode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(node.label)
                    .font(.headline)

                Spacer()

                Text(node.type == "Concept" ? "개념" : "노트")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(node.type == "Concept" ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2))
                    .cornerRadius(8)

                Button {
                    graphViewModel.selectNode(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            // 관련 노트 (개념인 경우)
            if node.type == "Concept" {
                let relatedNotes = getRelatedNotes(for: node)
                if !relatedNotes.isEmpty {
                    Divider()

                    Text("관련 노트")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(relatedNotes) { note in
                                RelatedNoteCard(note: note)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 10, y: -5)
        )
        .padding()
    }

    // 노드에 연결된 노트 찾기
    private func getRelatedNotes(for node: GraphDisplayNode) -> [NoteListItem] {
        // 엣지를 통해 연결된 노트 노드 찾기
        let connectedNoteIds = graphViewModel.edges
            .filter { $0.sourceId == node.id || $0.targetId == node.id }
            .flatMap { [$0.sourceId, $0.targetId] }
            .filter { id in
                graphViewModel.nodes.first { $0.id == id }?.type == "Note"
            }

        // 노트 ID로 NoteStore에서 노트 찾기
        return connectedNoteIds.compactMap { noteId in
            if let uuid = UUID(uuidString: noteId),
               let note = noteStore.notes.first(where: { $0.id == uuid }) {
                // Convert Note to NoteListItem
                return NoteListItem(
                    id: note.id,
                    thumbnail_url: note.thumbnailUrl,
                    description: note.description,
                    concepts: note.concepts,
                    created_at: ISO8601DateFormatter().string(from: note.createdAt)
                )
            }
            return nil
        }
    }
}

// MARK: - Graph Node View
struct GraphNodeView: View {
    let node: GraphDisplayNode
    let isSelected: Bool

    private var nodeColor: Color {
        node.type == "Concept" ? .blue : .orange
    }

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(isSelected ? nodeColor : nodeColor.opacity(0.7))
                .frame(width: 50, height: 50)
                .overlay {
                    if node.type == "Concept" {
                        Text(String(node.label.prefix(2)))
                            .font(.headline)
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "note.text")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                }
                .shadow(color: isSelected ? nodeColor.opacity(0.5) : .clear, radius: 8)

            Text(node.label)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: 80)
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Related Note Card
struct RelatedNoteCard: View {
    let note: NoteListItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let thumbnailUrl = note.thumbnail_url,
               let url = APIService.shared.getThumbnailURL(for: thumbnailUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 64, height: 64)
                        .clipped()
                } placeholder: {
                    Image(systemName: "note.text")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 64, height: 64)
                }
            } else {
                Image(systemName: "note.text")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 64, height: 64)
            }
            
            Text(note.description ?? "노트")
                .font(.caption)
                .lineLimit(2)
        }
        .frame(width: 80, height: 100)
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Edge Type Legend
struct EdgeTypeLegend: View {
    private let edgeTypes: [(name: String, color: Color)] = [
        ("REQUIRES", .red),
        ("CONTAINS", .blue),
        ("LEADS_TO", .green),
        ("RELATED", .gray)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("관계 유형")
                .font(.headline)

            ForEach(edgeTypes, id: \.name) { type in
                HStack {
                    Rectangle()
                        .fill(type.color)
                        .frame(width: 30, height: 3)

                    Text(type.name)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(12)
    }
}

#Preview {
    GraphView()
        .environmentObject(GraphViewModel())
        .environmentObject(NoteStore())
}
