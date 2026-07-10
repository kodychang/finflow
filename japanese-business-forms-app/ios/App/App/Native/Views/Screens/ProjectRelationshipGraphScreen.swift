import SwiftUI
import UIKit

struct ProjectRelationshipGraphScreen: View {
    @ObservedObject var store: DocumentStore
    let projectID: ProjectArchive.ID?
    @Binding var selectedSection: AppSection
    var onOpenDocument: (BusinessDocument) -> Void
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var selectedDocumentID: BusinessDocument.ID?
    @State private var linkSourceID: BusinessDocument.ID?
    @State private var scale: CGFloat = 1
    @State private var canvasOffset: CGSize = .zero
    @State private var activeScale: CGFloat?
    @State private var activeCanvasOffset: CGSize?
    @State private var dragStartOffset: CGSize?
    @State private var magnificationStartScale: CGFloat?
    @State private var magnificationStartOffset: CGSize?
    @State private var magnificationAnchor: UnitPoint = .center
    @State private var lockedMagnificationAnchor: CGPoint?
    @State private var magnificationViewSize: CGSize = .zero
    @State private var canvasGestureLock: ProjectGraphCanvasGestureLock = .idle
    @State private var canvasGestureSerial = 0
    @State private var storedPositions: [String: ProjectGraphStoredPoint] = [:]
    @State private var isDraggingNode = false
    @State private var draggingNodeID: String?
    @State private var liveDraggedNodePosition: CGPoint?
    @State private var nodeDragStartPosition: CGPoint?
    @State private var thumbnailCache: [String: UIImage] = [:]
    @State private var failedThumbnailIDs: Set<String> = []
    @State private var pendingActionDocumentID: BusinessDocument.ID?
    @State private var hasFittedInitialCanvas = false
    @State private var fitCanvasRequest = 0

    private var language: AppLanguage { store.interfaceLanguage }
    private var project: ProjectArchive? {
        guard let projectID else { return store.projects.first }
        return store.projects.first { $0.id == projectID }
    }

    private var nodes: [ProjectGraphNode] {
        guard let project else { return [] }
        let documentsByType = Dictionary(grouping: project.documents) { $0.type }
        var positionedDocuments: [(document: BusinessDocument, typeIndex: Int, rowIndex: Int)] = []

        for (typeIndex, type) in project.direction.requiredTypes.enumerated() {
            let documents = (documentsByType[type] ?? []).sorted { $0.updatedAt > $1.updatedAt }
            let columnDocuments = documents.isEmpty ? [BusinessDocument.graphPlaceholder(project: project, type: type)] : documents
            for (rowIndex, document) in columnDocuments.enumerated() {
                positionedDocuments.append((document, typeIndex, rowIndex))
            }
        }

        return positionedDocuments.enumerated().map { index, item in
            let layoutKey = ProjectGraphNode.layoutKey(for: item.document)
            let defaultPosition = ProjectGraphNode.defaultPosition(typeIndex: item.typeIndex, rowIndex: item.rowIndex)
            let storedPosition = storedPositions[layoutKey]?.point ?? defaultPosition
            let livePosition = draggingNodeID == layoutKey ? liveDraggedNodePosition : nil
            return ProjectGraphNode(
                document: item.document,
                index: index,
                total: positionedDocuments.count,
                typeIndex: item.typeIndex,
                rowIndex: item.rowIndex,
                layoutKey: layoutKey,
                position: livePosition ?? storedPosition
            )
        }
    }

    private var renderedNodes: [ProjectGraphNode] {
        nodes.map { $0.offsetBy(ProjectGraphNode.renderOrigin) }
    }

    private var relationEdges: [ProjectGraphEdge] {
        let realNodes = renderedNodes.filter { !$0.document.isGraphPlaceholder }
        return realNodes.flatMap { source in
            relatedNumbers(for: source.document).compactMap { relatedNumber in
                guard let target = realNodes.first(where: { $0.document.number == relatedNumber }) else {
                    return nil
                }
                let obstacleRects = realNodes
                    .filter { $0.id != source.id && $0.id != target.id }
                    .map(\.rect)
                return ProjectGraphEdge(
                    source: source,
                    target: target,
                    label: relatedNumber,
                    color: ProjectGraphEdge.color(for: source.typeIndex),
                    obstacles: obstacleRects
                )
            }
        }
    }

    private var connectionControls: [ProjectGraphConnectionControl] {
        let realNodes = renderedNodes.filter { !$0.document.isGraphPlaceholder && !$0.document.number.isEmpty }
        var controls: [ProjectGraphConnectionControl] = []
        var seen: Set<String> = []

        for edge in relationEdges {
            let key = ProjectGraphConnectionControl.key(source: edge.source, target: edge.target)
            seen.insert(key)
            controls.append(ProjectGraphConnectionControl(
                source: edge.source,
                target: edge.target,
                color: edge.color,
                position: edge.buttonPosition,
                isLinked: true
            ))
        }

        let groupedByType = Dictionary(grouping: realNodes) { $0.typeIndex }
        for typeIndex in groupedByType.keys.sorted() {
            let column = (groupedByType[typeIndex] ?? []).sorted { $0.rowIndex < $1.rowIndex }
            for pairIndex in 0..<max(column.count - 1, 0) {
                let source = column[pairIndex]
                let target = column[pairIndex + 1]
                let key = ProjectGraphConnectionControl.key(source: source, target: target)
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                controls.append(ProjectGraphConnectionControl(
                    source: source,
                    target: target,
                    color: ProjectGraphEdge.color(for: source.typeIndex),
                    position: CGPoint(x: source.position.x, y: (source.position.y + target.position.y) / 2),
                    isLinked: isRelated(source.document, toNumber: target.document.number)
                ))
            }
        }

        let horizontalPairCount = max((project?.direction.requiredTypes.count ?? 0) - 1, 0)
        for typeIndex in 0..<horizontalPairCount {
            let leftColumn = (groupedByType[typeIndex] ?? []).sorted { $0.rowIndex < $1.rowIndex }
            let rightColumn = (groupedByType[typeIndex + 1] ?? []).sorted { $0.rowIndex < $1.rowIndex }
            guard !leftColumn.isEmpty, !rightColumn.isEmpty else { continue }
            let rowCount = max(leftColumn.count, rightColumn.count)
            for rowIndex in 0..<rowCount {
                guard let source = leftColumn[safe: min(rowIndex, leftColumn.count - 1)],
                      let target = rightColumn[safe: min(rowIndex, rightColumn.count - 1)] else { continue }
                let key = ProjectGraphConnectionControl.key(source: source, target: target)
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                controls.append(ProjectGraphConnectionControl(
                    source: source,
                    target: target,
                    color: ProjectGraphEdge.color(for: source.typeIndex),
                    position: CGPoint(x: (source.position.x + target.position.x) / 2, y: (source.position.y + target.position.y) / 2),
                    isLinked: isRelated(source.document, toNumber: target.document.number)
                ))
            }
        }

        return controls
    }

    private var selectedDocument: BusinessDocument? {
        guard let selectedDocumentID else { return nil }
        return project?.documents.first { $0.id == selectedDocumentID }
    }

    private var pendingActionDocument: BusinessDocument? {
        guard let pendingActionDocumentID else { return nil }
        return project?.documents.first { $0.id == pendingActionDocumentID }
    }

    private var visibleScale: CGFloat {
        activeScale ?? scale
    }

    private var visibleCanvasOffset: CGSize {
        activeCanvasOffset ?? canvasOffset
    }

    private var isCanvasGestureActive: Bool {
        canvasGestureLock != .idle
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let project {
                graphCanvas
                    .zIndex(0)
                graphOverlay(project: project)
                    .zIndex(100)
                if let document = pendingActionDocument {
                    nodeActionOverlay(document: document)
                        .zIndex(200)
                }
            } else {
                Color.appBackground
                VStack(spacing: 14) {
                    HStack {
                        Button {
                            selectedSection = .projects
                        } label: {
                            Image(systemName: "xmark")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(ProjectGraphIconButtonStyle(accent: buttonAccent))
                        .accessibilityLabel(localizedExitTitle)
                        Spacer()
                    }
                    SectionCard(title: localizedTitle, titleWeight: .regular) {
                        EmptyManagementText(text: localizedEmptyProjectText)
                    }
                }
                .padding(18)
            }
        }
        .ignoresSafeArea()
        .background(Color.appBackground.ignoresSafeArea())
        .statusBar(hidden: true)
        .onAppear {
            loadLayout()
            warmThumbnailCache()
        }
        .onChange(of: projectID) { _ in
            selectedDocumentID = nil
            linkSourceID = nil
            resetCanvasGestureState()
            draggingNodeID = nil
            liveDraggedNodePosition = nil
            nodeDragStartPosition = nil
            pendingActionDocumentID = nil
            hasFittedInitialCanvas = false
            thumbnailCache = [:]
            failedThumbnailIDs = []
            loadLayout()
            warmThumbnailCache()
        }
        .onChange(of: fitCanvasRequest) { _ in
            hasFittedInitialCanvas = false
        }
        .onChange(of: store.pdfLanguageId) { _ in
            thumbnailCache = [:]
            failedThumbnailIDs = []
            warmThumbnailCache()
        }
    }

    private var graphCanvas: some View {
        let contentSize = ProjectGraphNode.canvasSize(for: renderedNodes)
        let layoutSignature = renderedNodes.map { "\($0.id):\(Int($0.position.x)):\(Int($0.position.y))" }.joined(separator: "|")
        return GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color.appBackground
                    .contentShape(Rectangle())

                ZStack(alignment: .topLeading) {
                    Canvas { context, _ in
                        for edge in relationEdges {
                            draw(edge: edge, in: &context)
                        }
                        if let linkSource = linkSourceID,
                           let source = renderedNodes.first(where: { $0.document.id == linkSource }) {
                            drawLinkModeRing(source: source, in: &context)
                        }
                    }
                    .frame(width: contentSize.width, height: contentSize.height)

                    ForEach(connectionControls) { control in
                        Menu {
                            if control.isLinked || isRelated(control.source.document, toNumber: control.target.document.number) {
                                Button(localizedClearRelationTitle, role: .destructive) {
                                    removeRelation(from: control.source.document, targetNumber: control.target.document.number)
                                }
                            } else {
                                Button(localizedStartLinkTitle) {
                                    appendRelation(from: control.source.document, to: control.target.document)
                                }
                            }
                            Button(control.target.document.type.localizedTitle(language)) {
                                selectedDocumentID = control.target.document.id
                            }
                        } label: {
                            Image(systemName: control.isLinked ? "link" : "plus")
                                .font(.caption.weight(.black))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(control.color)
                                .overlay(Circle().stroke(Color.white.opacity(0.86), lineWidth: 1.5))
                                .clipShape(Circle())
                        }
                        .menuStyle(BorderlessButtonMenuStyle())
                        .accessibilityLabel(control.isLinked ? localizedDeleteRelationTitle : localizedStartLinkTitle)
                        .position(control.position)
                        .allowsHitTesting(!isDraggingNode && !isCanvasGestureActive)
                    }

                    ForEach(renderedNodes) { node in
                        ProjectGraphDocumentNode(
                            node: node,
                            language: language,
                            isSelected: selectedDocumentID == node.document.id,
                            isLinkSource: linkSourceID == node.document.id,
                            isDragging: false,
                            accent: buttonAccent,
                            thumbnail: thumbnailCache[node.thumbnailCacheKey],
                            didFailThumbnail: failedThumbnailIDs.contains(node.thumbnailCacheKey),
                            isCanvasGestureActive: isCanvasGestureActive,
                            onTap: {
                                guard !isCanvasGestureActive else { return }
                                handleNodeTap(node.document)
                            },
                            onOpen: {
                                guard !isCanvasGestureActive else { return }
                                openDocumentIfAvailable(node.document)
                            }
                        )
                        .frame(width: ProjectGraphNode.cardSize.width, height: ProjectGraphNode.cardSize.height)
                        .position(node.position)
                        .zIndex(10 + Double(node.index) * 0.01)
                        .highPriorityGesture(nodeDragGesture(for: node), including: .gesture)
                    }
                }
                .frame(width: contentSize.width, height: contentSize.height)
                .scaleEffect(visibleScale, anchor: .topLeading)
                .offset(visibleCanvasOffset)
                .highPriorityGesture(canvasDragGesture, including: .gesture)
                .highPriorityGesture(canvasMagnificationGesture(in: proxy.size), including: .gesture)

                ProjectGraphPinchLocationReader { location, size, gestureScale, state in
                    magnificationViewSize = size
                    guard size.width > 0, size.height > 0 else { return }
                    magnificationAnchor = UnitPoint(
                        x: min(max(location.x / size.width, 0), 1),
                        y: min(max(location.y / size.height, 0), 1)
                    )
                    if state == .began {
                        lockedMagnificationAnchor = location
                    } else if state == .ended || state == .cancelled || state == .failed {
                        lockedMagnificationAnchor = nil
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)

            }
            .onAppear {
                magnificationViewSize = proxy.size
                DispatchQueue.main.async {
                    fitCanvasToContent(in: proxy.size)
                }
            }
            .onChange(of: projectID) { _ in
                DispatchQueue.main.async {
                    fitCanvasToContent(in: proxy.size)
                }
            }
            .onChange(of: layoutSignature) { _ in
                hasFittedInitialCanvas = false
                DispatchQueue.main.async {
                    fitCanvasToContent(in: proxy.size)
                }
            }
            .onChange(of: fitCanvasRequest) { _ in
                DispatchQueue.main.async {
                    fitCanvasToContent(in: proxy.size)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func graphOverlay(project: ProjectArchive) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    selectedSection = .projects
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(ProjectGraphIconButtonStyle(accent: buttonAccent))
                .accessibilityLabel(localizedExitTitle)

                Text(project.name)
                    .font(.caption.weight(.bold))
                    .foregroundColor(.appInk)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            graphToolbar(project: project)
                .frame(maxWidth: 520)

            Spacer()

            selectedDocumentPanel(project: project)
                .frame(maxWidth: 520)
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea()
        .compositingGroup()
    }

    private func nodeActionOverlay(document: BusinessDocument) -> some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    pendingActionDocumentID = nil
                }

            ProjectGraphNodeActionPopup(
                title: document.type.localizedTitle(language),
                subtitle: document.number.isEmpty ? localizedNoNumberText : document.number,
                editTitle: localizedEditFormTitle,
                relateTitle: localizedAssociateActionTitle,
                clearTitle: localizedCancelRelationActionTitle,
                cancelTitle: localizedCancelDialogTitle,
                accent: buttonAccent,
                onEdit: {
                    pendingActionDocumentID = nil
                    openDocumentIfAvailable(document)
                },
                onRelate: {
                    pendingActionDocumentID = nil
                    selectedDocumentID = document.id
                    linkSourceID = document.id
                },
                onClear: {
                    clearAllRelations(for: document)
                    pendingActionDocumentID = nil
                },
                onCancel: {
                    pendingActionDocumentID = nil
                }
            )
            .padding(.top, 92)
            .padding(.trailing, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .ignoresSafeArea()
    }

    private var canvasDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !isDraggingNode,
                      canvasGestureLock == .idle || canvasGestureLock == .panning else { return }
                canvasGestureLock = .panning
                let start = dragStartOffset ?? canvasOffset
                dragStartOffset = start
                activeCanvasOffset = CGSize(
                    width: start.width + value.translation.width,
                    height: start.height + value.translation.height
                )
            }
            .onEnded { _ in
                if let activeCanvasOffset {
                    canvasOffset = activeCanvasOffset
                }
                activeCanvasOffset = nil
                dragStartOffset = nil
                releaseCanvasGestureLock()
            }
    }

    private func canvasMagnificationGesture(in viewSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard !isDraggingNode,
                      canvasGestureLock == .idle || canvasGestureLock == .pinching else { return }
                canvasGestureLock = .pinching
                updateCanvasMagnification(value, anchor: lockedMagnificationAnchor ?? magnificationAnchorPoint(in: viewSize))
            }
            .onEnded { _ in
                if let activeScale {
                    scale = activeScale
                }
                if let activeCanvasOffset {
                    canvasOffset = activeCanvasOffset
                }
                activeScale = nil
                activeCanvasOffset = nil
                magnificationStartScale = nil
                magnificationStartOffset = nil
                lockedMagnificationAnchor = nil
                releaseCanvasGestureLock()
            }
    }

    private func magnificationAnchorPoint(in fallbackSize: CGSize) -> CGPoint {
        let size = magnificationViewSize == .zero ? fallbackSize : magnificationViewSize
        return CGPoint(
            x: size.width * magnificationAnchor.x,
            y: size.height * magnificationAnchor.y
        )
    }

    private func updateCanvasMagnification(_ value: CGFloat, anchor: CGPoint) {
        let startScale = magnificationStartScale ?? scale
        let startOffset = magnificationStartOffset ?? canvasOffset
        magnificationStartScale = startScale
        magnificationStartOffset = startOffset
        let nextScale = min(max(startScale * value, 0.05), 20)
        let contentPoint = CGPoint(
            x: (anchor.x - startOffset.width) / max(startScale, 0.0001),
            y: (anchor.y - startOffset.height) / max(startScale, 0.0001)
        )
        activeScale = nextScale
        activeCanvasOffset = CGSize(
            width: anchor.x - contentPoint.x * nextScale,
            height: anchor.y - contentPoint.y * nextScale
        )
    }

    private func zoomCanvas(by factor: CGFloat) {
        let startScale = scale
        let nextScale = min(max(scale * factor, 0.05), 20)
        let size = magnificationViewSize == .zero ? CGSize(width: 390, height: 844) : magnificationViewSize
        let anchor = CGPoint(x: size.width / 2, y: size.height / 2)
        let contentPoint = CGPoint(
            x: (anchor.x - canvasOffset.width) / max(startScale, 0.0001),
            y: (anchor.y - canvasOffset.height) / max(startScale, 0.0001)
        )
        scale = nextScale
        canvasOffset = CGSize(
            width: anchor.x - contentPoint.x * nextScale,
            height: anchor.y - contentPoint.y * nextScale
        )
    }

    private func fitCanvasToContent(in viewSize: CGSize) {
        guard !hasFittedInitialCanvas, !renderedNodes.isEmpty else { return }
        let bounds = renderedNodes
            .map(\.rect)
            .reduce(renderedNodes[0].rect) { $0.union($1) }
            .insetBy(dx: -70, dy: -70)

        let safeWidth = max(viewSize.width - 32, 1)
        let safeHeight = max(viewSize.height - 250, 1)
        let target = CGRect(
            x: 16,
            y: 190,
            width: safeWidth,
            height: safeHeight
        )
        let nextScale = min(1, max(0.05, min(target.width / max(bounds.width, 1), target.height / max(bounds.height, 1))))
        scale = nextScale
        activeScale = nil
        canvasOffset = CGSize(
            width: target.midX - bounds.midX * nextScale,
            height: target.midY - bounds.midY * nextScale
        )
        activeCanvasOffset = nil
        hasFittedInitialCanvas = true
    }

    private func releaseCanvasGestureLock() {
        canvasGestureSerial += 1
        let serial = canvasGestureSerial
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            guard serial == canvasGestureSerial else { return }
            canvasGestureLock = .idle
        }
    }

    private func resetCanvasGestureState() {
        canvasGestureSerial += 1
        canvasGestureLock = .idle
        activeScale = nil
        activeCanvasOffset = nil
        dragStartOffset = nil
        magnificationStartScale = nil
        magnificationStartOffset = nil
        lockedMagnificationAnchor = nil
    }

    private func nodeDragGesture(for node: ProjectGraphNode) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                guard canvasGestureLock == .idle || draggingNodeID == node.id else { return }
                if draggingNodeID == nil {
                    draggingNodeID = node.id
                    nodeDragStartPosition = node.position
                    pendingActionDocumentID = nil
                }
                isDraggingNode = true
                let start = nodeDragStartPosition ?? node.position
                let effectiveScale = max(visibleScale, 0.0001)
                let renderedPosition = CGPoint(
                    x: start.x + value.translation.width / effectiveScale,
                    y: start.y + value.translation.height / effectiveScale
                )
                liveDraggedNodePosition = ProjectGraphNode.modelPosition(fromRenderedPosition: renderedPosition)
            }
            .onEnded { value in
                guard draggingNodeID == node.id else {
                    resetNodeDragState()
                    return
                }
                let start = nodeDragStartPosition ?? node.position
                let effectiveScale = max(visibleScale, 0.0001)
                let renderedPosition = CGPoint(
                    x: start.x + value.translation.width / effectiveScale,
                    y: start.y + value.translation.height / effectiveScale
                )
                move(node: node, to: renderedPosition, shouldPersist: true)
                resetNodeDragState()
            }
    }

    private func resetNodeDragState() {
        isDraggingNode = false
        draggingNodeID = nil
        liveDraggedNodePosition = nil
        nodeDragStartPosition = nil
    }

    private func graphToolbar(project: ProjectArchive) -> some View {
        SectionCard(title: localizedOverviewTitle, titleWeight: .regular) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Label(project.direction.localizedTitle(language), systemImage: project.direction == .customer ? "person.crop.square" : "building.2")
                    Spacer()
                    Text("\(project.completedCount)/\(project.direction.requiredTypes.count)")
                        .font(.caption.weight(.black))
                        .foregroundColor(buttonAccent)
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(.appMuted)

                HStack(spacing: 8) {
                    Button {
                        organizeLayout()
                    } label: {
                        Label(localizedOrganizeTitle, systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ProjectGraphToolbarButtonStyle(isActive: false, accent: buttonAccent))

                    Button {
                        linkSourceID = nil
                    } label: {
                        Label(localizedCancelLinkTitle, systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ProjectGraphToolbarButtonStyle(isActive: linkSourceID == nil, accent: buttonAccent))

                    Button {
                        zoomCanvas(by: 0.88)
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ProjectGraphToolbarButtonStyle(isActive: false, accent: buttonAccent))

                    Button {
                        zoomCanvas(by: 1.14)
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ProjectGraphToolbarButtonStyle(isActive: false, accent: buttonAccent))
                }
            }
        }
    }

    @ViewBuilder
    private func selectedDocumentPanel(project: ProjectArchive) -> some View {
        SectionCard(title: localizedSelectedTitle, titleWeight: .regular) {
            if let selectedDocument {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedDocument.type.localizedTitle(language))
                                .font(.subheadline.weight(.black))
                                .foregroundColor(.appInk)
                            Text(selectedDocument.number.isEmpty ? localizedNoNumberText : selectedDocument.number)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.appMuted)
                        }
                        Spacer()
                        Button {
                            linkSourceID = selectedDocument.id
                        } label: {
                            Image(systemName: "link.badge.plus")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(ProjectGraphIconButtonStyle(accent: buttonAccent))
                        .accessibilityLabel(localizedStartLinkTitle)
                    }

                    Menu {
                        Button(localizedClearRelationTitle, role: .destructive) {
                            store.updateRelatedNumber(for: selectedDocument.id, relatedNumber: "")
                        }
                        ForEach(project.documents.filter { $0.id != selectedDocument.id && !$0.number.isEmpty }) { target in
                            Button("\(target.type.localizedTitle(language)) / \(target.number)") {
                                appendRelation(from: selectedDocument, to: target)
                            }
                        }
                    } label: {
                        Label(relationText(for: selectedDocument), systemImage: "number")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.appInk)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 12)
                            .background(Color.appInputBackground)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
                            .cornerRadius(8)
                    }

                    Button {
                        onOpenDocument(selectedDocument)
                    } label: {
                        Label(localizedOpenFormTitle, systemImage: "doc.text.magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ProjectGraphPrimaryButtonStyle(accent: buttonAccent))
                }
            } else {
                EmptyManagementText(text: localizedSelectNodeText)
            }
        }
    }

    private func handleNodeTap(_ document: BusinessDocument) {
        guard !document.isGraphPlaceholder else { return }
        if let linkSourceID, linkSourceID != document.id {
            if !document.number.isEmpty,
               let source = project?.documents.first(where: { $0.id == linkSourceID }) {
                appendRelation(from: source, to: document)
            }
            self.linkSourceID = nil
            pendingActionDocumentID = nil
            selectedDocumentID = document.id
            return
        }
        selectedDocumentID = document.id
        pendingActionDocumentID = document.id
    }

    private func openDocumentIfAvailable(_ document: BusinessDocument) {
        guard !document.isGraphPlaceholder else { return }
        onOpenDocument(document)
    }

    private func clearAllRelations(for document: BusinessDocument) {
        store.updateRelatedNumber(for: document.id, relatedNumber: "")
        let number = document.number.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !number.isEmpty else { return }
        for relatedDocument in project?.documents ?? [] where relatedDocument.id != document.id {
            if isRelated(relatedDocument, toNumber: number) {
                removeRelation(from: relatedDocument, targetNumber: number)
            }
        }
        if linkSourceID == document.id {
            linkSourceID = nil
        }
    }

    private func relatedNumbers(for document: BusinessDocument) -> [String] {
        document.relatedNumber
            .components(separatedBy: CharacterSet(charactersIn: "/,，、;；\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func isRelated(_ document: BusinessDocument, toNumber number: String) -> Bool {
        relatedNumbers(for: document).contains(number.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func appendRelation(from source: BusinessDocument, to target: BusinessDocument) {
        let targetNumber = target.number.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetNumber.isEmpty else { return }
        var numbers = relatedNumbers(for: source)
        guard !numbers.contains(targetNumber) else { return }
        numbers.append(targetNumber)
        store.updateRelatedNumber(for: source.id, relatedNumber: numbers.joined(separator: " / "))
    }

    private func removeRelation(from source: BusinessDocument, targetNumber: String) {
        let cleanTargetNumber = targetNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let numbers = relatedNumbers(for: source).filter { $0 != cleanTargetNumber }
        store.updateRelatedNumber(for: source.id, relatedNumber: numbers.joined(separator: " / "))
    }

    private func move(node: ProjectGraphNode, to position: CGPoint, shouldPersist: Bool) {
        var nextPositions = storedPositions
        let modelPosition = ProjectGraphNode.modelPosition(fromRenderedPosition: position)
        let nextPoint = ProjectGraphStoredPoint(modelPosition)
        if nextPositions[node.layoutKey] == nextPoint {
            return
        }
        nextPositions[node.layoutKey] = nextPoint
        storedPositions = nextPositions
        if shouldPersist {
            persistLayout()
        }
    }

    private func organizeLayout() {
        resetCanvasGestureState()
        hasFittedInitialCanvas = false
        fitCanvasRequest += 1
    }

    private func loadLayout() {
        guard let project else {
            storedPositions = [:]
            return
        }
        guard let data = UserDefaults.standard.data(forKey: layoutStorageKey(for: project.id)),
              let positions = try? JSONDecoder().decode([String: ProjectGraphStoredPoint].self, from: data) else {
            storedPositions = [:]
            return
        }
        storedPositions = positions
    }

    private func persistLayout(positions: [String: ProjectGraphStoredPoint]? = nil) {
        guard let project else { return }
        let positionsToSave = positions ?? storedPositions
        guard let data = try? JSONEncoder().encode(positionsToSave) else { return }
        UserDefaults.standard.set(data, forKey: layoutStorageKey(for: project.id))
    }

    private func layoutStorageKey(for projectID: ProjectArchive.ID) -> String {
        "native.shokoForms.projectGraph.positions.\(projectID.uuidString).v3"
    }

    private func warmThumbnailCache() {
        for node in nodes where !node.document.isGraphPlaceholder {
            let cacheKey = node.thumbnailCacheKey
            guard thumbnailCache[cacheKey] == nil,
                  !failedThumbnailIDs.contains(cacheKey) else { continue }
            do {
                let image = try DocumentPDFExporter.previewImage(for: node.document, language: store.pdfLanguage, scale: 0.55)
                thumbnailCache[cacheKey] = image
            } catch {
                failedThumbnailIDs.insert(cacheKey)
            }
        }
    }

    private func draw(edge: ProjectGraphEdge, in context: inout GraphicsContext) {
        let visibleLineWidth = max(2 / max(visibleScale, 0.0001), 2)
        context.stroke(edge.path, with: .color(edge.color.opacity(0.96)), style: StrokeStyle(lineWidth: visibleLineWidth, lineCap: .round, lineJoin: .round))
        drawEndpoint(at: edge.startPoint, color: edge.color, in: &context)
        drawArrowhead(from: edge.startPoint, to: edge.endPoint, color: edge.color, in: &context)
        drawEndpoint(at: edge.endPoint, color: edge.color, in: &context)

        let labelPoint = CGPoint(x: edge.buttonPosition.x, y: edge.buttonPosition.y + 28)
        context.draw(
            Text(edge.label)
                .font(.caption2.weight(.bold))
                .foregroundColor(edge.color),
            at: labelPoint
        )
    }

    private func drawEndpoint(at point: CGPoint, color: Color, in context: inout GraphicsContext) {
        let radius = max(7 / max(visibleScale, 0.0001), 7)
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(color))
        context.stroke(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.92)), lineWidth: max(1.4 / max(visibleScale, 0.0001), 1.4))
    }

    private func drawArrowhead(from start: CGPoint, to end: CGPoint, color: Color, in context: inout GraphicsContext) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let size = max(11 / max(visibleScale, 0.0001), 11)
        let endpointGap = max(15 / max(visibleScale, 0.0001), 15)
        let tip = CGPoint(
            x: end.x - cos(angle) * endpointGap,
            y: end.y - sin(angle) * endpointGap
        )
        let left = CGPoint(
            x: tip.x - cos(angle - .pi / 6) * size,
            y: tip.y - sin(angle - .pi / 6) * size
        )
        let right = CGPoint(
            x: tip.x - cos(angle + .pi / 6) * size,
            y: tip.y - sin(angle + .pi / 6) * size
        )
        var path = Path()
        path.move(to: tip)
        path.addLine(to: left)
        path.addLine(to: right)
        path.closeSubpath()
        context.fill(path, with: .color(color.opacity(0.96)))
    }

    private func drawLinkModeRing(source: ProjectGraphNode, in context: inout GraphicsContext) {
        let visibleLineWidth = max(2.5 / max(visibleScale, 0.0001), 3)
        let rect = CGRect(
            x: source.position.x - ProjectGraphNode.cardSize.width / 2 - 8,
            y: source.position.y - ProjectGraphNode.cardSize.height / 2 - 8,
            width: ProjectGraphNode.cardSize.width + 16,
            height: ProjectGraphNode.cardSize.height + 16
        )
        context.stroke(Path(roundedRect: rect, cornerRadius: 14), with: .color(buttonAccent), style: StrokeStyle(lineWidth: visibleLineWidth, dash: [7, 5]))
    }

    private func relationText(for document: BusinessDocument) -> String {
        let relatedNumber = document.relatedNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if relatedNumber.isEmpty {
            return localizedNoRelationText
        }
        return "\(localizedRelationTitle): \(relatedNumber)"
    }

    private var localizedTitle: String {
        switch language {
        case .japanese: return "プロジェクト関係グリッド"
        case .simplifiedChinese, .traditionalChinese: return "项目关系网格"
        case .english, .korean, .nepali, .french, .vietnamese: return "Project Relationship Grid"
        }
    }

    private var localizedOverviewTitle: String {
        switch language {
        case .japanese: return "グリッド表示"
        case .simplifiedChinese, .traditionalChinese: return "网格视图"
        case .english, .korean, .nepali, .french, .vietnamese: return "Grid View"
        }
    }

    private var localizedSelectedTitle: String {
        switch language {
        case .japanese: return "選択中の帳票"
        case .simplifiedChinese, .traditionalChinese: return "选中的表单"
        case .english, .korean, .nepali, .french, .vietnamese: return "Selected Form"
        }
    }

    private var localizedExitTitle: String {
        switch language {
        case .japanese: return "閉じる"
        case .simplifiedChinese, .traditionalChinese: return "离开"
        case .english, .korean, .nepali, .french, .vietnamese: return "Exit"
        }
    }

    private var localizedCancelLinkTitle: String {
        switch language {
        case .japanese: return "関連解除"
        case .simplifiedChinese, .traditionalChinese: return "取消连线"
        case .english, .korean, .nepali, .french, .vietnamese: return "Cancel Link"
        }
    }

    private var localizedOrganizeTitle: String {
        switch language {
        case .japanese: return "全体表示"
        case .simplifiedChinese, .traditionalChinese: return "显示全部"
        case .english, .korean, .nepali, .french, .vietnamese: return "Fit All"
        }
    }

    private var localizedStartLinkTitle: String {
        switch language {
        case .japanese: return "関連を作成"
        case .simplifiedChinese, .traditionalChinese: return "建立关联"
        case .english, .korean, .nepali, .french, .vietnamese: return "Create Relation"
        }
    }

    private var localizedClearRelationTitle: String {
        switch language {
        case .japanese: return "関連番号を空にする"
        case .simplifiedChinese, .traditionalChinese: return "清空关联编号"
        case .english, .korean, .nepali, .french, .vietnamese: return "Clear Reference No."
        }
    }

    private var localizedDeleteRelationTitle: String {
        switch language {
        case .japanese: return "関連線を削除"
        case .simplifiedChinese, .traditionalChinese: return "删除关联线"
        case .english, .korean, .nepali, .french, .vietnamese: return "Delete relation line"
        }
    }

    private var localizedOpenFormTitle: String {
        switch language {
        case .japanese: return "帳票を開く"
        case .simplifiedChinese, .traditionalChinese: return "打开表单"
        case .english, .korean, .nepali, .french, .vietnamese: return "Open Form"
        }
    }

    private var localizedEditFormTitle: String {
        switch language {
        case .japanese: return "編集"
        case .simplifiedChinese, .traditionalChinese: return "编辑"
        case .english, .korean, .nepali, .french, .vietnamese: return "Edit"
        }
    }

    private var localizedAssociateActionTitle: String {
        switch language {
        case .japanese: return "関連"
        case .simplifiedChinese, .traditionalChinese: return "关联"
        case .english, .korean, .nepali, .french, .vietnamese: return "Relate"
        }
    }

    private var localizedCancelRelationActionTitle: String {
        switch language {
        case .japanese: return "関連解除"
        case .simplifiedChinese, .traditionalChinese: return "取消关联"
        case .english, .korean, .nepali, .french, .vietnamese: return "Clear relation"
        }
    }

    private var localizedCancelDialogTitle: String {
        switch language {
        case .japanese: return "キャンセル"
        case .simplifiedChinese, .traditionalChinese: return "取消"
        case .english, .korean, .nepali, .french, .vietnamese: return "Cancel"
        }
    }

    private var localizedSelectNodeText: String {
        switch language {
        case .japanese: return "帳票カードを選択すると、関連番号を編集できます。"
        case .simplifiedChinese, .traditionalChinese: return "选择表单卡片后，可以编辑关联编号。"
        case .english, .korean, .nepali, .french, .vietnamese: return "Select a form card to edit its reference number."
        }
    }

    private var localizedEmptyProjectText: String {
        switch language {
        case .japanese: return "表示できるプロジェクトがありません。"
        case .simplifiedChinese, .traditionalChinese: return "没有可显示的项目。"
        case .english, .korean, .nepali, .french, .vietnamese: return "No project is available."
        }
    }

    private var localizedNoRelationText: String {
        switch language {
        case .japanese: return "関連番号なし"
        case .simplifiedChinese, .traditionalChinese: return "无关联编号"
        case .english, .korean, .nepali, .french, .vietnamese: return "No reference number"
        }
    }

    private var localizedRelationTitle: String {
        switch language {
        case .japanese: return "関連番号"
        case .simplifiedChinese, .traditionalChinese: return "关联编号"
        case .english, .korean, .nepali, .french, .vietnamese: return "Reference No."
        }
    }

    private var localizedNoNumberText: String {
        switch language {
        case .japanese: return "番号なし"
        case .simplifiedChinese, .traditionalChinese: return "无编号"
        case .english, .korean, .nepali, .french, .vietnamese: return "No number"
        }
    }
}

private struct ProjectGraphDocumentNode: View {
    let node: ProjectGraphNode
    let language: AppLanguage
    let isSelected: Bool
    let isLinkSource: Bool
    let isDragging: Bool
    let accent: Color
    let thumbnail: UIImage?
    let didFailThumbnail: Bool
    let isCanvasGestureActive: Bool
    let onTap: () -> Void
    let onOpen: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            formPreview

            nodeIcon
                .padding(6)

            if !node.document.isGraphPlaceholder {
                Button(action: onOpen) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption2.weight(.black))
                        .foregroundColor(.white.opacity(0.82))
                        .frame(width: 27, height: 27)
                        .background(Color.black.opacity(0.36))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity, alignment: .topTrailing)
                .padding(6)
            }

            nodeInfoOverlay
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor, lineWidth: isSelected || isLinkSource ? 2 : 1))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(isDragging ? 0.12 : 0.04), radius: isDragging ? 12 : 4, x: 0, y: isDragging ? 8 : 2)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            guard !isCanvasGestureActive else { return }
            onTap()
        }
    }

    private var formPreview: some View {
        ZStack {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(width: ProjectGraphNode.cardSize.width, height: ProjectGraphNode.cardSize.height)
                    .background(Color.white)
            } else if didFailThumbnail || node.document.isGraphPlaceholder {
                VStack(spacing: 4) {
                    previewLine(width: 0.72)
                    previewLine(width: 0.94)
                    previewLine(width: 0.58)
                    HStack(spacing: 4) {
                        previewCell
                        previewCell
                        previewCell
                    }
                    previewLine(width: 0.84)
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(node.document.isGraphPlaceholder ? accent.opacity(0.08) : Color.appInputBackground)
            } else {
                ProgressView()
                    .scaleEffect(0.72)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appInputBackground)
            }
        }
        .frame(width: ProjectGraphNode.cardSize.width, height: ProjectGraphNode.cardSize.height)
    }

    private var nodeIcon: some View {
        Image(systemName: node.document.isGraphPlaceholder ? "doc.badge.plus" : "doc.text.fill")
            .font(.caption2.weight(.black))
            .foregroundColor(node.document.isGraphPlaceholder ? accent : .white.opacity(0.86))
            .frame(width: 25, height: 25)
            .background(node.document.isGraphPlaceholder ? Color.appPanel.opacity(0.78) : accent.opacity(0.78))
            .clipShape(Circle())
    }

    private var nodeInfoOverlay: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(node.document.type.localizedTitle(language))
                .font(.caption2.weight(.black))
                .foregroundColor(.white.opacity(0.82))
                .lineLimit(1)
            Text(node.document.number.isEmpty ? localizedNumberFallback : node.document.number)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white.opacity(0.66))
                .lineLimit(1)
            Text(node.document.relatedNumber.isEmpty ? localizedNoRelationText : node.document.relatedNumber)
                .font(.caption2.weight(.semibold))
                .foregroundColor(node.document.relatedNumber.isEmpty ? .white.opacity(0.48) : accent.opacity(0.82))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: ProjectGraphNode.cardSize.width - 14, alignment: .leading)
        .background(Color.black.opacity(0.46))
        .cornerRadius(7)
        .padding(6)
    }

    private func previewLine(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(node.document.isGraphPlaceholder ? accent.opacity(0.20) : Color.appDivider)
            .frame(width: ProjectGraphNode.cardSize.width * width * 0.58, height: 5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var previewCell: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(node.document.colorTemplate.swiftUIColor.opacity(node.document.isGraphPlaceholder ? 0.16 : 0.42))
            .frame(height: 14)
    }

    private var borderColor: Color {
        if isLinkSource { return accent }
        if isSelected { return accent.opacity(0.85) }
        return Color.appDivider
    }

    private var localizedNumberFallback: String {
        switch language {
        case .japanese: return node.document.isGraphPlaceholder ? "未作成" : "番号なし"
        case .simplifiedChinese, .traditionalChinese: return node.document.isGraphPlaceholder ? "未创建" : "无编号"
        case .english, .korean, .nepali, .french, .vietnamese: return node.document.isGraphPlaceholder ? "Not created" : "No number"
        }
    }

    private var localizedNoRelationText: String {
        switch language {
        case .japanese: return "関連なし"
        case .simplifiedChinese, .traditionalChinese: return "无关联"
        case .english, .korean, .nepali, .french, .vietnamese: return "No relation"
        }
    }

}

private struct ProjectGraphNodeActionPopup: View {
    let title: String
    let subtitle: String
    let editTitle: String
    let relateTitle: String
    let clearTitle: String
    let cancelTitle: String
    let accent: Color
    let onEdit: () -> Void
    let onRelate: () -> Void
    let onClear: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.black))
                        .foregroundColor(.appInk)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.appMuted)
                        .lineLimit(1)
                }
                Spacer(minLength: 10)
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.black))
                        .foregroundColor(.appMuted)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            popupButton(title: editTitle, systemImage: "square.and.pencil", action: onEdit)
            popupButton(title: relateTitle, systemImage: "link.badge.plus", action: onRelate)
            popupButton(title: clearTitle, systemImage: "link.badge.minus", roleColor: .red, action: onClear)

            Divider()

            Button(action: onCancel) {
                Text(cancelTitle)
                    .font(.caption.weight(.bold))
                    .foregroundColor(.appMuted)
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(width: 218)
        .background(Color.appPanel)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.16), radius: 18, x: 0, y: 10)
    }

    private func popupButton(title: String, systemImage: String, roleColor: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.black))
                    .foregroundColor(roleColor ?? accent)
                    .frame(width: 22)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(roleColor ?? .appInk)
                Spacer()
            }
            .frame(minHeight: 42)
            .padding(.horizontal, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private enum ProjectGraphCanvasGestureLock {
    case idle
    case panning
    case pinching
}

private struct ProjectGraphPinchLocationReader: UIViewRepresentable {
    var onChange: (CGPoint, CGSize, CGFloat, UIGestureRecognizer.State) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = ProjectGraphPinchCaptureView(frame: .zero)
        view.backgroundColor = .clear
        let recognizer = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = context.coordinator
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onChange = onChange
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChange: (CGPoint, CGSize, CGFloat, UIGestureRecognizer.State) -> Void

        init(onChange: @escaping (CGPoint, CGSize, CGFloat, UIGestureRecognizer.State) -> Void) {
            self.onChange = onChange
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            guard let view = recognizer.view else { return }
            onChange(recognizer.location(in: view), view.bounds.size, recognizer.scale, recognizer.state)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

private final class ProjectGraphPinchCaptureView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        (event?.allTouches?.count ?? 0) >= 2 && bounds.contains(point)
    }
}

private struct ProjectGraphNode: Identifiable {
    static let cardSize = CGSize(width: 158, height: 174)
    static let columnSpacing: CGFloat = 320
    static let rowSpacing: CGFloat = 252
    static let gridOrigin = CGPoint(x: 132, y: 154)
    static let renderOrigin = CGPoint(x: 8_000, y: 8_000)
    static let canvasExtent = CGSize(width: 18_000, height: 18_000)
    static let initialCanvasOffset = CGSize(width: 24 - renderOrigin.x, height: 84 - renderOrigin.y)
    let document: BusinessDocument
    let index: Int
    let total: Int
    let typeIndex: Int
    let rowIndex: Int
    let layoutKey: String
    let position: CGPoint

    var id: String {
        layoutKey
    }

    var thumbnailCacheKey: String {
        "\(layoutKey)-\(document.updatedAt.timeIntervalSince1970)"
    }

    static func layoutKey(for document: BusinessDocument) -> String {
        document.isGraphPlaceholder ? "placeholder-\(document.type.rawValue)" : document.id.uuidString
    }

    static func defaultPosition(typeIndex: Int, rowIndex: Int) -> CGPoint {
        CGPoint(
            x: gridOrigin.x + CGFloat(typeIndex) * columnSpacing,
            y: gridOrigin.y + CGFloat(rowIndex) * rowSpacing
        )
    }

    static func canvasSize(for nodes: [ProjectGraphNode]) -> CGSize {
        let maxX = nodes.map(\.position.x).max() ?? canvasExtent.width
        let maxY = nodes.map(\.position.y).max() ?? canvasExtent.height
        return CGSize(
            width: max(canvasExtent.width, maxX + cardSize.width / 2 + 500),
            height: max(canvasExtent.height, maxY + cardSize.height / 2 + 500)
        )
    }

    static func modelPosition(fromRenderedPosition position: CGPoint) -> CGPoint {
        CGPoint(x: position.x - renderOrigin.x, y: position.y - renderOrigin.y)
    }

    func offsetBy(_ origin: CGPoint) -> ProjectGraphNode {
        ProjectGraphNode(
            document: document,
            index: index,
            total: total,
            typeIndex: typeIndex,
            rowIndex: rowIndex,
            layoutKey: layoutKey,
            position: CGPoint(x: position.x + origin.x, y: position.y + origin.y)
        )
    }
}

private struct ProjectGraphStoredPoint: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat

    init(_ point: CGPoint) {
        x = point.x
        y = point.y
    }

    var point: CGPoint {
        CGPoint(x: x, y: y)
    }
}

private struct ProjectGraphConnectionControl: Identifiable {
    let source: ProjectGraphNode
    let target: ProjectGraphNode
    let color: Color
    let position: CGPoint
    let isLinked: Bool

    var id: String {
        Self.key(source: source, target: target)
    }

    static func key(source: ProjectGraphNode, target: ProjectGraphNode) -> String {
        "\(source.id)-\(target.id)"
    }
}

private struct ProjectGraphEdge: Identifiable {
    let source: ProjectGraphNode
    let target: ProjectGraphNode
    let label: String
    let color: Color
    let obstacles: [CGRect]

    var id: String {
        "\(source.id)-\(target.id)-\(label)"
    }

    var path: Path {
        route.path
    }

    var buttonPosition: CGPoint {
        route.buttonPosition
    }

    var startPoint: CGPoint {
        route.startPoint
    }

    var endPoint: CGPoint {
        route.endPoint
    }

    private var route: ProjectGraphEdgeRoute {
        let sourceRect = source.rect
        let targetRect = target.rect
        let clearance: CGFloat = 36
        let ports = ports(from: sourceRect, to: targetRect)
        let start = portPoint(in: sourceRect, port: ports.source)
        let end = portPoint(in: targetRect, port: ports.target)
        let leadOut = offset(start, from: ports.source, by: clearance)
        let leadIn = offset(end, from: ports.target, by: clearance)

        switch (ports.source.axis, ports.target.axis) {
        case (.horizontal, .horizontal):
            let laneX = verticalLaneX(start: leadOut, end: leadIn)
            return orthogonalRoute(
                points: [
                    start,
                    leadOut,
                    CGPoint(x: laneX, y: leadOut.y),
                    CGPoint(x: laneX, y: leadIn.y),
                    leadIn,
                    end
                ]
            )
        case (.vertical, .vertical):
            let laneY = horizontalLaneY(start: leadOut, end: leadIn)
            return orthogonalRoute(
                points: [
                    start,
                    leadOut,
                    CGPoint(x: leadOut.x, y: laneY),
                    CGPoint(x: leadIn.x, y: laneY),
                    leadIn,
                    end
                ]
            )
        default:
            let corner = CGPoint(x: leadIn.x, y: leadOut.y)
            let alternateCorner = CGPoint(x: leadOut.x, y: leadIn.y)
            let preferredCorner = routeSegmentHitsObstacles(from: leadOut, to: corner) || routeSegmentHitsObstacles(from: corner, to: leadIn) ? alternateCorner : corner
            return orthogonalRoute(points: [start, leadOut, preferredCorner, leadIn, end])
        }
    }

    private func ports(from sourceRect: CGRect, to targetRect: CGRect) -> (source: ProjectGraphEdgePort, target: ProjectGraphEdgePort) {
        let dx = targetRect.midX - sourceRect.midX
        let dy = targetRect.midY - sourceRect.midY
        if abs(dx) >= abs(dy) {
            return dx >= 0 ? (.right, .left) : (.left, .right)
        }
        return dy >= 0 ? (.bottom, .top) : (.top, .bottom)
    }

    private func portPoint(in rect: CGRect, port: ProjectGraphEdgePort) -> CGPoint {
        switch port {
        case .top:
            return CGPoint(x: rect.midX, y: rect.minY)
        case .bottom:
            return CGPoint(x: rect.midX, y: rect.maxY)
        case .left:
            return CGPoint(x: rect.minX, y: rect.midY)
        case .right:
            return CGPoint(x: rect.maxX, y: rect.midY)
        }
    }

    private func offset(_ point: CGPoint, from port: ProjectGraphEdgePort, by distance: CGFloat) -> CGPoint {
        switch port {
        case .top:
            return CGPoint(x: point.x, y: point.y - distance)
        case .bottom:
            return CGPoint(x: point.x, y: point.y + distance)
        case .left:
            return CGPoint(x: point.x - distance, y: point.y)
        case .right:
            return CGPoint(x: point.x + distance, y: point.y)
        }
    }

    private func orthogonalRoute(points rawPoints: [CGPoint]) -> ProjectGraphEdgeRoute {
        let points = deduplicated(points: rawPoints)

        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }

        return ProjectGraphEdgeRoute(
            path: path,
            buttonPosition: buttonPosition(for: points),
            startPoint: points[0],
            endPoint: points[points.count - 1]
        )
    }

    private func deduplicated(points: [CGPoint]) -> [CGPoint] {
        points.reduce(into: []) { result, point in
            if result.last != point {
                result.append(point)
            }
        }
    }

    private func buttonPosition(for points: [CGPoint]) -> CGPoint {
        guard points.count > 2 else {
            return CGPoint(x: (points[0].x + points[points.count - 1].x) / 2, y: (points[0].y + points[points.count - 1].y) / 2)
        }
        return points[points.count / 2]
    }

    private func verticalLaneX(start: CGPoint, end: CGPoint) -> CGFloat {
        let midpoint = (start.x + end.x) / 2
        let corridor = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y) - 28,
            width: abs(end.x - start.x),
            height: abs(end.y - start.y) + 56
        )
        let hits = obstacles.map { $0.insetBy(dx: -22, dy: -22) }.filter { $0.intersects(corridor) }
        guard !hits.isEmpty else { return midpoint }
        let left = hits.map(\.minX).min() ?? midpoint
        let right = hits.map(\.maxX).max() ?? midpoint
        return abs(midpoint - left) > abs(midpoint - right) ? left - 34 : right + 34
    }

    private func horizontalLaneY(start: CGPoint, end: CGPoint) -> CGFloat {
        let midpoint = (start.y + end.y) / 2
        let corridor = CGRect(
            x: min(start.x, end.x) - 28,
            y: min(start.y, end.y),
            width: abs(end.x - start.x) + 56,
            height: abs(end.y - start.y)
        )
        let hits = obstacles.map { $0.insetBy(dx: -22, dy: -22) }.filter { $0.intersects(corridor) }
        guard !hits.isEmpty else { return midpoint }
        let top = hits.map(\.minY).min() ?? midpoint
        let bottom = hits.map(\.maxY).max() ?? midpoint
        return abs(midpoint - top) > abs(midpoint - bottom) ? top - 34 : bottom + 34
    }

    private func routeSegmentHitsObstacles(from start: CGPoint, to end: CGPoint) -> Bool {
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: max(abs(end.x - start.x), 1),
            height: max(abs(end.y - start.y), 1)
        ).insetBy(dx: -8, dy: -8)
        return obstacles.map { $0.insetBy(dx: -22, dy: -22) }.contains { $0.intersects(rect) }
    }

    private func directRoute(start: CGPoint, end: CGPoint, horizontalDirection: CGFloat) -> ProjectGraphEdgeRoute {
        let distance = max(120, abs(end.x - start.x) * 0.52)
        var path = Path()
        path.move(to: start)
        path.addCurve(
            to: end,
            control1: CGPoint(x: start.x + distance * horizontalDirection, y: start.y),
            control2: CGPoint(x: end.x - distance * horizontalDirection, y: end.y)
        )
        return ProjectGraphEdgeRoute(path: path, buttonPosition: cubicPoint(t: 0.5, start: start, control1: CGPoint(x: start.x + distance * horizontalDirection, y: start.y), control2: CGPoint(x: end.x - distance * horizontalDirection, y: end.y), end: end), startPoint: start, endPoint: end)
    }

    private func directRoute(start: CGPoint, end: CGPoint, verticalDirection: CGFloat) -> ProjectGraphEdgeRoute {
        let distance = max(110, abs(end.y - start.y) * 0.48)
        var path = Path()
        path.move(to: start)
        path.addCurve(
            to: end,
            control1: CGPoint(x: start.x, y: start.y + distance * verticalDirection),
            control2: CGPoint(x: end.x, y: end.y - distance * verticalDirection)
        )
        return ProjectGraphEdgeRoute(path: path, buttonPosition: cubicPoint(t: 0.5, start: start, control1: CGPoint(x: start.x, y: start.y + distance * verticalDirection), control2: CGPoint(x: end.x, y: end.y - distance * verticalDirection), end: end), startPoint: start, endPoint: end)
    }

    private func detourRoute(start: CGPoint, end: CGPoint, corner: CGPoint) -> ProjectGraphEdgeRoute {
        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: corner, control: CGPoint(x: start.x, y: corner.y))
        path.addQuadCurve(to: end, control: CGPoint(x: end.x, y: corner.y))
        return ProjectGraphEdgeRoute(path: path, buttonPosition: corner, startPoint: start, endPoint: end)
    }

    private func horizontalDetourY(start: CGPoint, end: CGPoint) -> CGFloat? {
        let corridor = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y) - 64,
            width: abs(end.x - start.x),
            height: abs(end.y - start.y) + 128
        )
        let hits = obstacles.map { $0.insetBy(dx: -24, dy: -24) }.filter { $0.intersects(corridor) }
        guard !hits.isEmpty else { return nil }
        return max(60, hits.map(\.minY).min() ?? min(start.y, end.y) - 96) - 78
    }

    private func verticalDetourX(start: CGPoint, end: CGPoint) -> CGFloat? {
        let corridor = CGRect(
            x: min(start.x, end.x) - 64,
            y: min(start.y, end.y),
            width: abs(end.x - start.x) + 128,
            height: abs(end.y - start.y)
        )
        let hits = obstacles.map { $0.insetBy(dx: -24, dy: -24) }.filter { $0.intersects(corridor) }
        guard !hits.isEmpty else { return nil }
        return max(60, hits.map(\.minX).min() ?? min(start.x, end.x) - 96) - 78
    }

    private func cubicPoint(t: CGFloat, start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint) -> CGPoint {
        let mt = 1 - t
        return CGPoint(
            x: mt * mt * mt * start.x + 3 * mt * mt * t * control1.x + 3 * mt * t * t * control2.x + t * t * t * end.x,
            y: mt * mt * mt * start.y + 3 * mt * mt * t * control1.y + 3 * mt * t * t * control2.y + t * t * t * end.y
        )
    }

    static func color(for index: Int) -> Color {
        let palette: [Color] = [
            Color(red: 0.95, green: 0.33, blue: 0.28),
            Color(red: 0.09, green: 0.50, blue: 0.76),
            Color(red: 0.20, green: 0.56, blue: 0.36),
            Color(red: 0.56, green: 0.35, blue: 0.84),
            Color(red: 0.88, green: 0.50, blue: 0.12),
        ]
        return palette[index % palette.count]
    }
}

private struct ProjectGraphEdgeRoute {
    let path: Path
    let buttonPosition: CGPoint
    let startPoint: CGPoint
    let endPoint: CGPoint
}

private enum ProjectGraphEdgeAxis {
    case horizontal
    case vertical
}

private enum ProjectGraphEdgePort {
    case top
    case bottom
    case left
    case right

    var axis: ProjectGraphEdgeAxis {
        switch self {
        case .left, .right:
            return .horizontal
        case .top, .bottom:
            return .vertical
        }
    }
}

private extension ProjectGraphNode {
    var rect: CGRect {
        CGRect(
            x: position.x - Self.cardSize.width / 2,
            y: position.y - Self.cardSize.height / 2,
            width: Self.cardSize.width,
            height: Self.cardSize.height
        )
    }
}

private struct ProjectGraphToolbarButtonStyle: ButtonStyle {
    let isActive: Bool
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.bold))
            .foregroundColor(isActive ? .white : accent)
            .frame(minHeight: 42)
            .padding(.horizontal, 10)
            .background(isActive ? accent : accent.opacity(configuration.isPressed ? 0.18 : 0.10))
            .cornerRadius(8)
    }
}

private struct ProjectGraphIconButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundColor(accent)
            .background(accent.opacity(configuration.isPressed ? 0.18 : 0.10))
            .clipShape(Circle())
    }
}

private struct ProjectGraphPrimaryButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundColor(.white)
            .frame(minHeight: 46)
            .padding(.horizontal, 12)
            .background(accent.opacity(configuration.isPressed ? 0.82 : 1))
            .cornerRadius(8)
    }
}

private extension BusinessDocument {
    var isGraphPlaceholder: Bool {
        number == "__graph_placeholder__"
    }

    static func graphPlaceholder(project: ProjectArchive, type: DocumentType) -> BusinessDocument {
        var document = BusinessDocument.blank(type: type, number: "__graph_placeholder__")
        document.projectId = project.id
        document.projectName = project.name
        document.projectDirection = project.direction
        document.customerName = project.customerName
        return document
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
