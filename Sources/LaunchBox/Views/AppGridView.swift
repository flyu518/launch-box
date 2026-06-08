import AppKit
import LaunchBoxCore
import SwiftUI

private enum GridEntryDropTarget: Hashable {
    case entry(String)
}

private enum KeyboardSelectionDirection {
    case up
    case down
    case left
    case right
}

private enum GridDropAction: Equatable {
    case reorder
    case createFolder
    case addToFolder(String)

    var label: String {
        switch self {
        case .reorder:
            return "排序"
        case .createFolder:
            return "建文件夹"
        case .addToFolder:
            return "加入文件夹"
        }
    }

    var subtitle: String {
        switch self {
        case .reorder:
            return "松手调整顺序"
        case .createFolder:
            return "松手创建文件夹"
        case .addToFolder(let title):
            return "松手加入“\(title)”"
        }
    }
}

struct AppGridView: View {
    @ObservedObject var store: LaunchStore
    @Binding var activeDrag: LauncherDragState?
    let onOpenApp: () -> Void
    let onBlankClick: () -> Void
    let onCustomDrop: (String, CGPoint) -> Bool
    let onSectionSwipe: (SectionNavigationDirection) -> Void

    @StateObject private var iconCache = IconCache()

    @State private var openedFolderID: String?
    @State private var folderRenameText = ""
    @State private var newCategoryName = ""
    @State private var categorySourceApp: LaunchApp?
    @State private var hoveredEntryID: GridEntry.ID?
    @State private var feedbackMessage: String?
    @State private var entryTargetFrames: [String: CGRect] = [:]
    @State private var mouseDragEntryID: GridEntry.ID?
    @State private var selectedEntryID: GridEntry.ID?

    private let columns = [
        GridItem(.adaptive(minimum: 104, maximum: 132), spacing: 22)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            ScrollView {
                if store.activeEntries.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity)
                        .padding(.top, 92)
                } else {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(store.activeEntries) { entry in
                            entryView(entry)
                                .entryDropTarget(entry.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .background {
                ScrollWheelSectionSwitcher(onSwipe: onSectionSwipe)
            }
            .simultaneousGesture(blankMouseSectionDragGesture)
            .simultaneousGesture(blankClickDismissGesture)
        }
        .onAppear {
            KeyboardCommandRouter.shared.handler = { event in
                handleKeyDown(event)
            }
        }
        .onDisappear {
            KeyboardCommandRouter.shared.handler = nil
        }
        .onPreferenceChange(GridEntryFramePreferenceKey.self) { frames in
            entryTargetFrames = frames
        }
        .onChange(of: store.activeEntries) { _, entries in
            if let selectedEntryID, entries.contains(where: { $0.id == selectedEntryID }) {
                return
            }
            selectedEntryID = entries.first?.id
        }
        .alert("新建分类并加入", isPresented: categoryPromptBinding) {
            TextField("分类名称", text: $newCategoryName)
            Button("创建") {
                createCategoryFromPrompt()
            }
            Button("取消", role: .cancel) {
                categorySourceApp = nil
            }
        }
        .overlay {
            folderPanelOverlay
        }
        .overlay(alignment: .bottom) {
            if let feedbackMessage {
                Text(feedbackMessage)
                    .font(.callout)
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(.regularMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.18), radius: 16, y: 8)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: emptyStateSystemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(emptyStateTitle)
                .font(.title3)
                .fontWeight(.semibold)

            if let subtitle = emptyStateSubtitle {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.vertical, 26)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
    }

    private var emptyStateTitle: String {
        if !store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "没有匹配的应用"
        }

        switch store.activeSection {
        case .all:
            return "暂无应用"
        case .favorites:
            return "暂无收藏"
        case .recent:
            return "暂无最近项目"
        case .uncategorized:
            return "未分类为空"
        case .category:
            return "这个分类还没有应用"
        case .hidden:
            return "暂无隐藏应用"
        }
    }

    private var emptyStateSubtitle: String? {
        if !store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "换个关键词试试"
        }
        return nil
    }

    private var emptyStateSystemImage: String {
        if !store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "magnifyingglass"
        }

        switch store.activeSection {
        case .favorites:
            return "star"
        case .recent:
            return "clock"
        case .uncategorized:
            return "tray"
        case .category:
            return "folder"
        case .hidden:
            return "eye.slash"
        case .all:
            return "square.grid.3x3"
        }
    }

    private var header: some View {
        HStack {
            Text(title)
                .font(.system(size: 28, weight: .bold))

            Spacer()

            Text("\(store.activeEntries.count)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.regularMaterial, in: Capsule())
        }
        .padding(.horizontal, 8)
    }

    private var title: String {
        switch store.activeSection {
        case .category(let categoryID):
            return store.categoryName(id: categoryID)
        default:
            return store.activeSection.title
        }
    }

    private var categoryPromptBinding: Binding<Bool> {
        Binding(
            get: { categorySourceApp != nil },
            set: { if !$0 { categorySourceApp = nil } }
        )
    }

    private var currentOpenedFolder: GridEntry? {
        guard let openedFolderID else {
            return nil
        }
        return store.folderEntry(id: openedFolderID)
    }

    private func entryView(_ entry: GridEntry) -> some View {
        let isHovered = hoveredEntryID == entry.id
        let isSelected = selectedEntryID == entry.id
        let dropAction = activeDropAction(for: entry)
        let isDropTarget = dropAction != nil

        return VStack(spacing: 8) {
            if let app = entry.app {
                Image(nsImage: iconCache.icon(for: app))
                    .resizable()
                    .frame(width: 74, height: 74)
                    .cornerRadius(16)
            } else {
                folderIcon(entry)
            }

            VStack(spacing: 1) {
                Text(entry.title)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 112, alignment: .top)
                    .fixedSize(horizontal: false, vertical: true)

                if let app = entry.app {
                    statusBadges(for: app)
                        .frame(width: 116, height: 18)
                }
            }
        }
        .frame(width: 122, height: 136, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(entryFill(isHovered: isHovered, dropAction: dropAction))
                .background {
                    if isHovered || isSelected || isDropTarget {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.thinMaterial)
                    }
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    entryStroke(
                        isHovered: isHovered,
                        isSelected: isSelected,
                        isDropTarget: isDropTarget,
                        dropAction: dropAction
                    ),
                    lineWidth: isDropTarget || isSelected ? 2 : 1
                )
        }
        .overlay(alignment: .leading) {
            if dropAction == .reorder {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: 4, height: 96)
                    .shadow(color: Color.accentColor.opacity(0.44), radius: 10)
                    .offset(x: -7)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topLeading) {
            if let dropAction {
                Text(dropAction.label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.accentColor, in: Capsule())
                    .padding(8)
                    .opacity(dropAction == .reorder ? 0.88 : 1)
                    .transition(.scale(scale: 0.86).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topTrailing) {
            dragHandle(for: entry, isVisible: isHovered)
                .padding(8)
        }
        .shadow(color: isHovered ? Color.black.opacity(0.10) : Color.clear, radius: 14, y: 6)
        .scaleEffect(isHovered || isSelected ? 1.035 : 1.0)
        .animation(.snappy(duration: 0.14), value: isHovered)
        .animation(.snappy(duration: 0.14), value: isSelected)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedEntryID = entry.id
            if let app = entry.app {
                onOpenApp()
                if !store.open(app) {
                    showFeedback("无法打开“\(app.name)”")
                }
            } else if let folder = entry.folder {
                openedFolderID = folder.id
                folderRenameText = folder.name
            }
        }
        .contextMenu {
            contextMenu(for: entry)
        }
        .onHover { isHovered in
            hoveredEntryID = isHovered ? entry.id : nil
        }
        .highPriorityGesture(customDragGesture(for: entry))
        .help(entry.app == nil ? "点击打开文件夹，按住拖动排序" : "点击打开应用，按住拖动移动")
    }

    private func dragHandle(for entry: GridEntry, isVisible: Bool) -> some View {
        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 24, height: 24)
            .background(.regularMaterial, in: Circle())
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.14), radius: 8, y: 3)
            .opacity(isVisible ? 1 : 0.001)
            .allowsHitTesting(isVisible)
            .contentShape(Circle())
            .highPriorityGesture(customDragGesture(for: entry))
            .help(entry.app == nil ? "按住拖动排序" : "按住拖动排序、建文件夹或加入分类")
    }

    private func customDragGesture(for entry: GridEntry) -> some Gesture {
        DragGesture(minimumDistance: 7, coordinateSpace: .named("launcherOverlay"))
            .onChanged { value in
                guard canDragEntry(entry), isLeftMouseButtonPressed else {
                    if mouseDragEntryID == entry.id {
                        mouseDragEntryID = nil
                        activeDrag = nil
                    }
                    return
                }

                if mouseDragEntryID == nil {
                    mouseDragEntryID = entry.id
                }

                guard mouseDragEntryID == entry.id else {
                    return
                }

                activeDrag = LauncherDragState(
                    dragID: entry.id,
                    title: entry.title,
                    subtitle: gridDragSubtitle(dragID: entry.id, at: value.location),
                    location: value.location,
                    entry: entry
                )
            }
            .onEnded { value in
                guard canDragEntry(entry), mouseDragEntryID == entry.id else {
                    activeDrag = nil
                    if mouseDragEntryID == entry.id {
                        mouseDragEntryID = nil
                    }
                    return
                }

                let dragID = entry.id
                activeDrag = nil
                mouseDragEntryID = nil
                if handleGridDrop(dragID: dragID, at: value.location) {
                    return
                }
                if entry.app != nil, onCustomDrop(dragID, value.location) {
                    return
                }
            }
    }

    private func canDragEntry(_ entry: GridEntry) -> Bool {
        if entry.app != nil {
            return true
        }

        return entry.folder != nil && canReorderEntries
    }

    private var isLeftMouseButtonPressed: Bool {
        NSEvent.pressedMouseButtons & 1 == 1
    }

    private func activeDropAction(for entry: GridEntry) -> GridDropAction? {
        guard let activeDrag,
              activeDrag.dragID != entry.id,
              entryTargetFrames[entry.id]?.insetBy(dx: -8, dy: -8).contains(activeDrag.location) == true else {
            return nil
        }

        return dropAction(for: entry, dragID: activeDrag.dragID, at: activeDrag.location)
    }

    private func handleGridDrop(dragID: String, at location: CGPoint) -> Bool {
        guard let targetEntry = targetEntry(dragID: dragID, at: location),
              let action = dropAction(for: targetEntry, dragID: dragID, at: location) else {
            return false
        }

        switch action {
        case .createFolder, .addToFolder:
            return handleNestDrop(dragID: dragID, targetEntry: targetEntry)
        case .reorder:
            store.moveEntry(dragID: dragID, before: targetEntry.id)
            showFeedback("已调整顺序")
            return true
        }
    }

    private var canReorderEntries: Bool {
        switch store.activeSection {
        case .all, .favorites, .uncategorized, .category, .hidden:
            return true
        case .recent:
            return false
        }
    }

    private var canNestEntries: Bool {
        if case .category = store.activeSection {
            return true
        }
        return false
    }

    private func isCenterDrop(on entry: GridEntry, at location: CGPoint) -> Bool {
        guard let frame = entryTargetFrames[entry.id] else {
            return false
        }

        let centerFrame = frame.insetBy(dx: frame.width * 0.26, dy: frame.height * 0.22)
        return centerFrame.contains(location)
    }

    private func targetEntry(dragID: String, at location: CGPoint) -> GridEntry? {
        store.activeEntries.first { entry in
            guard entry.id != dragID,
                  entryTargetFrames[entry.id]?.insetBy(dx: -8, dy: -8).contains(location) == true else {
                return false
            }
            return canReorderEntries || canNestEntries
        }
    }

    private func dropAction(for entry: GridEntry, dragID: String, at location: CGPoint) -> GridDropAction? {
        guard canReorderEntries || canNestEntries else {
            return nil
        }

        if isFolderDragID(dragID) {
            return canReorderEntries ? .reorder : nil
        }

        if canNestEntries, isCenterDrop(on: entry, at: location) {
            if entry.app != nil {
                return .createFolder
            }
            if entry.folder != nil {
                return .addToFolder(entry.title)
            }
        }

        if canReorderEntries {
            return .reorder
        }

        return nil
    }

    private func isFolderDragID(_ dragID: String) -> Bool {
        LaunchDragID(rawValue: dragID)?.isFolder == true
    }

    private func gridDragSubtitle(dragID: String, at location: CGPoint) -> String {
        guard let targetEntry = targetEntry(dragID: dragID, at: location),
              let action = dropAction(for: targetEntry, dragID: dragID, at: location) else {
            return defaultDragSubtitle
        }

        return action.subtitle
    }

    private var defaultDragSubtitle: String {
        if case .category = store.activeSection {
            return "拖到应用、文件夹、收藏、分类或隐藏"
        }
        return "拖到目标位置排序，或拖到收藏/分类/隐藏"
    }

    private func entryFill(isHovered: Bool, dropAction: GridDropAction?) -> Color {
        if let dropAction {
            switch dropAction {
            case .reorder:
                return Color.white.opacity(0.16)
            case .createFolder, .addToFolder:
                return Color.accentColor.opacity(0.18)
            }
        }

        return isHovered ? Color.white.opacity(0.22) : Color.clear
    }

    private func entryStroke(
        isHovered: Bool,
        isSelected: Bool,
        isDropTarget: Bool,
        dropAction: GridDropAction?
    ) -> Color {
        if dropAction == .reorder {
            return .clear
        }
        if isDropTarget || isSelected {
            return Color.accentColor.opacity(0.86)
        }
        if isHovered {
            return Color.white.opacity(0.34)
        }
        return .clear
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard let command = KeyboardCommandClassifier.command(
            for: LauncherKeyboardInput(
                keyCode: UInt16(event.keyCode),
                hasCommand: event.modifierFlags.contains(.command),
                hasOption: event.modifierFlags.contains(.option),
                hasControl: event.modifierFlags.contains(.control),
                hasShift: event.modifierFlags.contains(.shift),
                isModalActive: NSApp.modalWindow != nil,
                isFolderOpen: openedFolderID != nil
            )
        ) else {
            return false
        }

        switch command {
        case .open:
            openSelectedEntry()
            return true
        case .moveLeft:
            moveSelection(.left)
            return true
        case .moveRight:
            moveSelection(.right)
            return true
        case .moveDown:
            moveSelection(.down)
            return true
        case .moveUp:
            moveSelection(.up)
            return true
        }
    }

    private func openSelectedEntry() {
        let entries = store.activeEntries
        let entry: GridEntry?
        if let selectedEntryID {
            entry = entries.first { $0.id == selectedEntryID } ?? entries.first
        } else {
            entry = entries.first
        }

        guard let entry else {
            return
        }

        if let app = entry.app {
            onOpenApp()
            if !store.open(app) {
                showFeedback("无法打开“\(app.name)”")
            }
        } else if let folder = entry.folder {
            openedFolderID = folder.id
            folderRenameText = folder.name
        }
    }

    private func moveSelection(_ direction: KeyboardSelectionDirection) {
        let entries = store.activeEntries
        guard !entries.isEmpty else {
            selectedEntryID = nil
            return
        }

        guard let currentSelectedEntryID = selectedEntryID,
              let currentIndex = entries.firstIndex(where: { $0.id == currentSelectedEntryID }) else {
            selectedEntryID = entries.first?.id
            return
        }

        let targetID: String?
        switch direction {
        case .left:
            targetID = entries[max(entries.startIndex, currentIndex - 1)].id
        case .right:
            targetID = entries[min(entries.index(before: entries.endIndex), currentIndex + 1)].id
        case .up, .down:
            targetID = verticalSelectionID(from: entries[currentIndex], direction: direction)
        }

        if let targetID {
            selectedEntryID = targetID
        }
    }

    private func verticalSelectionID(from entry: GridEntry, direction: KeyboardSelectionDirection) -> String? {
        guard let currentFrame = entryTargetFrames[entry.id] else {
            return entry.id
        }

        let candidates = entryTargetFrames.filter { id, frame in
            guard id != entry.id else {
                return false
            }
            switch direction {
            case .up:
                return frame.midY < currentFrame.midY
            case .down:
                return frame.midY > currentFrame.midY
            case .left, .right:
                return false
            }
        }

        return candidates.min { lhs, rhs in
            let lhsScore = abs(lhs.value.midX - currentFrame.midX) + abs(lhs.value.midY - currentFrame.midY)
            let rhsScore = abs(rhs.value.midX - currentFrame.midX) + abs(rhs.value.midY - currentFrame.midY)
            return lhsScore < rhsScore
        }?.key
    }

    private var blankMouseSectionDragGesture: some Gesture {
        DragGesture(minimumDistance: 36, coordinateSpace: .named("launcherOverlay"))
            .onEnded { value in
                guard activeDrag == nil,
                      store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !startsInsideEntry(value.startLocation) else {
                    return
                }

                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > 88,
                      abs(horizontal) > abs(vertical) * 1.45 else {
                    return
                }

                onSectionSwipe(horizontal < 0 ? .next : .previous)
            }
    }

    private var blankClickDismissGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("launcherOverlay"))
            .onEnded { value in
                guard activeDrag == nil,
                      openedFolderID == nil,
                      isLeftClickWithoutMeaningfulMovement(value),
                      !startsInsideEntry(value.startLocation) else {
                    return
                }

                onBlankClick()
            }
    }

    private func isLeftClickWithoutMeaningfulMovement(_ value: DragGesture.Value) -> Bool {
        guard isPrimaryClickOrReleased else {
            return false
        }

        return abs(value.translation.width) < 4 && abs(value.translation.height) < 4
    }

    private var isPrimaryClickOrReleased: Bool {
        NSEvent.pressedMouseButtons == 0 || NSEvent.pressedMouseButtons & 1 == 1
    }

    private func startsInsideEntry(_ location: CGPoint) -> Bool {
        entryTargetFrames.values.contains { frame in
            frame.insetBy(dx: -6, dy: -6).contains(location)
        }
    }

    private func handleNestDrop(dragID: String, targetEntry: GridEntry) -> Bool {
        if targetEntry.app != nil {
            guard let folder = store.createFolderFromDrag(dragID, onto: targetEntry.id),
                  let folderID = folder.folder?.id else {
                return false
            }

            openedFolderID = folderID
            folderRenameText = folder.title
            showFeedback("已创建文件夹")
            return true
        }

        guard targetEntry.folder != nil,
              let folder = store.addDraggedApp(dragID, toFolder: targetEntry.id) else {
            return false
        }

        showFeedback("已加入“\(folder.title)”")
        return true
    }

    private func folderIcon(_ entry: GridEntry) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
                .frame(width: 74, height: 74)

            LazyVGrid(columns: [GridItem(), GridItem()], spacing: 5) {
                ForEach(entry.folderApps.prefix(4), id: \.id) { app in
                    Image(nsImage: iconCache.icon(for: app))
                        .resizable()
                        .frame(width: 26, height: 26)
                        .cornerRadius(6)
                }
            }
            .frame(width: 58, height: 58)
        }
    }

    @ViewBuilder
    private var folderPanelOverlay: some View {
        if let folder = currentOpenedFolder {
            ZStack {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        openedFolderID = nil
                    }

                FolderContentsView(
                    store: store,
                    iconCache: iconCache,
                    folder: folder,
                    activeDrag: $activeDrag,
                    folderName: $folderRenameText,
                    onOpenApp: onOpenApp,
                    onFeedback: showFeedback,
                    onClose: {
                        openedFolderID = nil
                    },
                    onRename: { name in
                        if let folderID = folder.folder?.id {
                            store.renameFolder(id: folderID, to: name)
                        }
                    },
                    onMoveOut: { app in
                        guard let folderID = folder.folder?.id else {
                            return
                        }

                        let folderStillExists = store.moveAppOutOfFolder(appID: app.id, folderID: folderID)
                        showFeedback("已移出“\(app.name)”")
                        if !folderStillExists {
                            openedFolderID = nil
                        }
                    }
                )
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private func contextMenu(for entry: GridEntry) -> some View {
        if let app = entry.app {
            if store.activeSection != .hidden {
                Button(store.isFavorite(app.id) ? "取消收藏" : "加入收藏") {
                    let willFavorite = !store.isFavorite(app.id)
                    store.toggleFavorite(appID: app.id)
                    showFeedback(willFavorite ? "已加入收藏" : "已取消收藏")
                }

                Menu("加入分类") {
                    ForEach(store.sortedCategories) { category in
                        Button {
                            let isAdded = store.toggleApp(app.id, inCategory: category.id)
                            showFeedback(isAdded ? "已加入“\(category.name)”" : "已从“\(category.name)”移除")
                        } label: {
                            if store.app(app.id, isInCategory: category.id) {
                                Label(category.name, systemImage: "checkmark")
                            } else {
                                Text(category.name)
                            }
                        }
                    }

                    Divider()

                    Button("新建分类并加入...") {
                        categorySourceApp = app
                        newCategoryName = ""
                    }
                }

                if case .category(let categoryID) = store.activeSection {
                    Button("从当前分类移除") {
                        store.removeEntry(entry)
                    }
                    .disabled(categoryID.isEmpty)
                }
            }

            if store.activeSection == .hidden {
                Button("取消隐藏") {
                    store.unhideApp(app.id)
                    showFeedback("已恢复“\(app.name)”")
                }
            } else {
                Button("隐藏此应用") {
                    store.hideApp(app.id)
                    showFeedback("已隐藏“\(app.name)”")
                }
            }

            Divider()

            Button("在 Finder 中显示") {
                onOpenApp()
                if !AppLauncher.revealInFinder(app) {
                    showFeedback("无法在 Finder 中显示“\(app.name)”")
                }
            }
        } else {
            Button("打开文件夹") {
                if let folder = entry.folder {
                    openedFolderID = folder.id
                    folderRenameText = folder.name
                }
            }

            if case .category = store.activeSection {
                Button("从当前分类移除") {
                    store.removeEntry(entry)
                }
            }
        }
    }

    private func createCategoryFromPrompt() {
        guard let categorySourceApp else {
            return
        }

        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        store.createCategory(named: newCategoryName, containing: categorySourceApp.id)
        if !trimmedName.isEmpty {
            showFeedback("已加入“\(trimmedName)”")
        }
        self.categorySourceApp = nil
    }

    private func statusBadges(for app: LaunchApp) -> some View {
        let badges = store.statusBadges(for: app)
        let visibleBadges = Array(badges.prefix(2))
        let remainingCount = max(0, badges.count - visibleBadges.count)

        return HStack(spacing: 3) {
            ForEach(visibleBadges, id: \.self) { badge in
                badgeView(badge)
            }

            if remainingCount > 0 {
                badgeView("+\(remainingCount)")
            }
        }
        .help(badges.joined(separator: "、"))
    }

    private func badgeView(_ title: String) -> some View {
        let isFavorite = title == "收藏"

        return Text(isFavorite ? "★" : title)
            .font(.system(size: 9, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, isFavorite ? 5 : 6)
            .padding(.vertical, 2)
            .foregroundStyle(Color.primary)
            .background(
                badgeBackground(isFavorite: isFavorite),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(badgeStroke(isFavorite: isFavorite), lineWidth: 1)
            }
    }

    private func badgeBackground(isFavorite: Bool) -> Color {
        if isFavorite {
            return Color.yellow.opacity(0.32)
        }
        return Color.accentColor.opacity(0.20)
    }

    private func badgeStroke(isFavorite: Bool) -> Color {
        if isFavorite {
            return Color.yellow.opacity(0.36)
        }
        return Color.accentColor.opacity(0.24)
    }

    private func showFeedback(_ message: String) {
        withAnimation(.snappy(duration: 0.16)) {
            feedbackMessage = message
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            guard feedbackMessage == message else {
                return
            }

            withAnimation(.snappy(duration: 0.18)) {
                feedbackMessage = nil
            }
        }
    }
}

private struct FolderContentsView: View {
    @ObservedObject var store: LaunchStore
    @ObservedObject var iconCache: IconCache
    let folder: GridEntry
    @Binding var activeDrag: LauncherDragState?
    @Binding var folderName: String
    let onOpenApp: () -> Void
    let onFeedback: (String) -> Void
    let onClose: () -> Void
    let onRename: (String) -> Void
    let onMoveOut: (LaunchApp) -> Void

    @State private var panelSize = CGSize(width: 560, height: 260)
    @State private var draggedApp: LaunchApp?
    @State private var folderDragLocation: CGPoint = .zero

    private let columns = [
        GridItem(.adaptive(minimum: 96, maximum: 120), spacing: 18)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                TextField("文件夹名称", text: $folderName)
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .fontWeight(.bold)
                    .onSubmit {
                        onRename(folderName)
                    }
                    .onChange(of: folderName) { _, newValue in
                        onRename(newValue)
                    }

                Spacer()
            }

            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(folder.folderApps) { app in
                    VStack(spacing: 8) {
                        Image(nsImage: iconCache.icon(for: app))
                            .resizable()
                            .frame(width: 64, height: 64)
                            .cornerRadius(14)

                        Text(app.name)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 104, height: 116)
                    .opacity(draggedApp?.id == app.id ? 0.28 : 1)
                    .scaleEffect(draggedApp?.id == app.id ? 0.94 : 1)
                    .animation(.snappy(duration: 0.14), value: draggedApp?.id)
                    .contentShape(Rectangle())
                    .highPriorityGesture(folderAppDragGesture(for: app))
                    .contextMenu {
                        Button("移出文件夹") {
                            onMoveOut(app)
                        }
                    }
                    .onTapGesture {
                        onOpenApp()
                        if !store.open(app) {
                            onFeedback("无法打开“\(app.name)”")
                        }
                    }
                }
            }

            Text("拖到面板外即可移出文件夹")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .overlay(alignment: .topLeading) {
            folderDragPreview
        }
        .padding(22)
        .frame(width: 560)
        .frame(minHeight: 260)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.24), radius: 30, y: 16)
        .coordinateSpace(name: "folderPanel")
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        panelSize = proxy.size
                    }
                    .onChange(of: proxy.size) { _, newSize in
                        panelSize = newSize
                    }
            }
        }
    }

    @ViewBuilder
    private var folderDragPreview: some View {
        if let draggedApp {
            VStack(spacing: 8) {
                Image(nsImage: iconCache.icon(for: draggedApp))
                    .resizable()
                    .frame(width: 64, height: 64)
                    .cornerRadius(14)

                Text(draggedApp.name)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 104)
            }
            .frame(width: 116, height: 126)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.30), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.22), radius: 18, y: 8)
            .scaleEffect(1.05)
            .position(folderDragLocation)
            .allowsHitTesting(false)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
            .zIndex(10)
        }
    }

    private func folderAppDragGesture(for app: LaunchApp) -> some Gesture {
        DragGesture(minimumDistance: 7, coordinateSpace: .named("folderPanel"))
            .onChanged { value in
                activeDrag = nil
                folderDragLocation = value.location
                if draggedApp?.id != app.id {
                    withAnimation(.snappy(duration: 0.12)) {
                        draggedApp = app
                    }
                }
            }
            .onEnded { value in
                activeDrag = nil
                let panelBounds = CGRect(origin: .zero, size: panelSize).insetBy(dx: -12, dy: -12)
                withAnimation(.snappy(duration: 0.14)) {
                    draggedApp = nil
                }
                if !panelBounds.contains(value.location) {
                    onMoveOut(app)
                }
            }
    }
}

private struct ScrollWheelSectionSwitcher: NSViewRepresentable {
    let onSwipe: (SectionNavigationDirection) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSwipe: onSwipe)
    }

    func makeNSView(context: Context) -> CaptureView {
        let view = CaptureView()
        view.coordinator = context.coordinator
        context.coordinator.view = view
        context.coordinator.onSwipe = onSwipe
        context.coordinator.install()
        return view
    }

    func updateNSView(_ nsView: CaptureView, context: Context) {
        nsView.coordinator = context.coordinator
        context.coordinator.view = nsView
        context.coordinator.onSwipe = onSwipe
    }

    static func dismantleNSView(_ nsView: CaptureView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class CaptureView: NSView {
        weak var coordinator: Coordinator?

        override var acceptsFirstResponder: Bool {
            true
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }

        override func scrollWheel(with event: NSEvent) {
            coordinator?.handle(event)
            super.scrollWheel(with: event)
        }

        override func swipe(with event: NSEvent) {
            coordinator?.handle(event)
            super.swipe(with: event)
        }
    }

    final class Coordinator {
        weak var view: CaptureView?
        var onSwipe: (SectionNavigationDirection) -> Void

        private var monitor: Any?
        private var accumulatedX: CGFloat = 0
        private var hasTriggeredInGesture = false
        private var lastEventAt = Date.distantPast

        init(onSwipe: @escaping (SectionNavigationDirection) -> Void) {
            self.onSwipe = onSwipe
        }

        func install() {
            guard monitor == nil else {
                return
            }

            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .swipe]) { [weak self] event in
                self?.handle(event)
                return event
            }
        }

        func uninstall() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        fileprivate func handle(_ event: NSEvent) {
            guard let view,
                  let window = view.window,
                  event.window === window else {
                return
            }

            let point = view.convert(event.locationInWindow, from: nil)
            guard view.bounds.contains(point) else {
                return
            }

            guard NSEvent.pressedMouseButtons & 1 == 0 else {
                resetGesture()
                return
            }

            switch event.type {
            case .scrollWheel:
                handleScrollWheel(event)
            case .swipe:
                handleSwipe(event)
            default:
                return
            }
        }

        private func handleScrollWheel(_ event: NSEvent) {
            let now = Date()
            if now.timeIntervalSince(lastEventAt) > 0.35 {
                resetGesture()
            }
            lastEventAt = now

            if event.phase == .began {
                resetGesture()
            }

            if event.phase == .ended || event.phase == .cancelled {
                resetGesture()
                return
            }

            guard event.momentumPhase.isEmpty else {
                return
            }

            let horizontal = event.scrollingDeltaX
            let vertical = event.scrollingDeltaY
            guard abs(horizontal) > abs(vertical) * 1.25,
                  abs(horizontal) > 0.5 else {
                return
            }

            accumulatedX += horizontal
            let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 55 : 5
            guard abs(accumulatedX) > threshold else {
                return
            }

            let direction: SectionNavigationDirection = accumulatedX < 0 ? .next : .previous
            trigger(direction)
        }

        private func handleSwipe(_ event: NSEvent) {
            let horizontal = event.deltaX
            let vertical = event.deltaY
            guard abs(horizontal) > abs(vertical),
                  abs(horizontal) > 0 else {
                return
            }

            trigger(horizontal > 0 ? .next : .previous)
        }

        private func trigger(_ direction: SectionNavigationDirection) {
            guard !hasTriggeredInGesture else {
                return
            }

            hasTriggeredInGesture = true
            accumulatedX = 0
            onSwipe(direction)
        }

        private func resetGesture() {
            accumulatedX = 0
            hasTriggeredInGesture = false
        }
    }
}

private struct GridEntryFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private extension View {
    func entryDropTarget(_ id: String) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: GridEntryFramePreferenceKey.self,
                    value: [id: proxy.frame(in: .named("launcherOverlay"))]
                )
            }
        }
    }

}
