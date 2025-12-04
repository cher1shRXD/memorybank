// Views/Graph/GraphView.swift
import SwiftUI

struct GraphView: View {
    @EnvironmentObject var graphViewModel: GraphViewModel
    @EnvironmentObject var noteStore: NoteStore
    
    @State private var showingConceptDetail = false
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
                
                // 선택된 개념 정보
                VStack {
                    Spacer()
                    
                    if let concept = graphViewModel.selectedConcept {
                        selectedConceptPanel(concept: concept)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3), value: graphViewModel.selectedConcept)
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
                graphViewModel.startSimulation()
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
            for relation in graphViewModel.relations {
                guard let source = graphViewModel.concepts.first(where: { $0.id == relation.sourceId }),
                      let target = graphViewModel.concepts.first(where: { $0.id == relation.targetId }) else {
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
                
                let strokeStyle: StrokeStyle
                if relation.type.isDashed {
                    strokeStyle = StrokeStyle(lineWidth: 2, dash: [5, 5])
                } else {
                    strokeStyle = StrokeStyle(lineWidth: 2)
                }
                
                context.stroke(path, with: .color(relation.type.color), style: strokeStyle)
                
                // 화살표 그리기
                if relation.type.hasArrow {
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
                    
                    context.stroke(arrowPath, with: .color(relation.type.color), style: StrokeStyle(lineWidth: 2))
                }
            }
        }
        .overlay {
            // 노드 그리기 (SwiftUI Views)
            GeometryReader { geometry in
                let centerOffset = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                ForEach(graphViewModel.concepts) { concept in
                    ConceptNodeView(
                        concept: concept,
                        isSelected: graphViewModel.selectedConcept?.id == concept.id
                    )
                    .position(
                        x: concept.position.x + centerOffset.x - 200,
                        y: concept.position.y + centerOffset.y - 300
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            if graphViewModel.selectedConcept?.id == concept.id {
                                graphViewModel.selectConcept(nil)
                            } else {
                                graphViewModel.selectConcept(concept)
                            }
                        }
                    }
                    .onLongPressGesture {
                        graphViewModel.focusOnConcept(concept)
                    }
                }
            }
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
    
    // MARK: - Selected Concept Panel
    private func selectedConceptPanel(concept: Concept) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(concept.name)
                    .font(.headline)
                
                Spacer()
                
                Button {
                    graphViewModel.selectConcept(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            
            if let description = concept.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // 관련 노트
            let relatedNotes = graphViewModel.getRelatedNotes(for: concept, in: noteStore)
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
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 10, y: -5)
        )
        .padding()
    }
}

// MARK: - Concept Node View
struct ConceptNodeView: View {
    let concept: Concept
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(isSelected ? Color.blue : Color.blue.opacity(0.7))
                .frame(width: 50, height: 50)
                .overlay {
                    Text(String(concept.name.prefix(2)))
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .shadow(color: isSelected ? .blue.opacity(0.5) : .clear, radius: 8)
            
            Text(concept.name)
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
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if note.hasPDF {
                Image(systemName: "doc.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
            } else {
                Image(systemName: "note.text")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            
            Text(note.title)
                .font(.caption)
                .lineLimit(2)
        }
        .frame(width: 80, height: 80)
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Edge Type Legend
struct EdgeTypeLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("관계 유형")
                .font(.headline)
            
            ForEach(RelationType.allCases, id: \.self) { type in
                HStack {
                    Rectangle()
                        .fill(type.color)
                        .frame(width: 30, height: 3)
                    
                    Text(type.rawValue)
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
