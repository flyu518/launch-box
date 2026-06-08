import LaunchBoxCore
import SwiftUI
import UniformTypeIdentifiers

struct LauncherDragState: Equatable {
    var dragID: String
    var title: String
    var subtitle: String
    var location: CGPoint
    var entry: GridEntry?
}

private struct CategoryDragState: Equatable {
    var categoryID: String
    var title: String
    var location: CGPoint
}

private enum CategoryDropDestination {
    case before(String)
    case end

    var targetID: String? {
        switch self {
        case .before(let id):
            return id
        case .end:
            return nil
        }
    }
}

enum LauncherDropTarget: Hashable {
    case favorites
    case category(String)
    case hidden
}

struct LauncherOverlayView: View {
    @ObservedObject var store: LaunchStore
    let onClose: () -> Void

    @StateObject private var iconCache = IconCache()

    @FocusState private var searchFocused: Bool
    @State private var isAddingCategory = false
    @State private var newCategoryName = ""
    @State private var categoryBeingRenamed: LaunchCategory?
    @State private var renameText = ""
    @State private var dropFeedback: String?
    @State private var activeDrag: LauncherDragState?
    @State private var categoryDrag: CategoryDragState?
    @State private var dropTargetFrames: [LauncherDropTarget: CGRect] = [:]
    @State private var categoryControlFrames: [String: CGRect] = [:]
    @State private var isRescanning = false

    var body: some View {
        ZStack {
            glassBackground

            VStack(spacing: 14) {
                topBar

                categoryStrip

                AppGridView(
                    store: store,
                    activeDrag: $activeDrag,
                    onOpenApp: onClose,
                    onBlankClick: onClose,
                    onCustomDrop: handleCustomDrop(dragID:at:),
                    onSectionSwipe: { direction in
                        withAnimation(.snappy(duration: 0.18)) {
                            store.moveActiveSection(direction)
                        }
                    }
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 28)
            .contentShape(Rectangle())

            dragPreview
            categoryDragPreview
        }
        .coordinateSpace(name: "launcherOverlay")
        .onPreferenceChange(DropTargetFramePreferenceKey.self) { frames in
            dropTargetFrames = frames
        }
        .onPreferenceChange(CategoryControlFramePreferenceKey.self) { frames in
            categoryControlFrames = frames
        }
        .onAppear {
            DispatchQueue.main.async {
                searchFocused = true
            }
        }
        .onExitCommand {
            if store.query.isEmpty {
                onClose()
            } else {
                store.query = ""
            }
        }
        .alert("新建分类", isPresented: $isAddingCategory) {
            TextField("分类名称", text: $newCategoryName)
            Button("创建") {
                store.createCategory(named: newCategoryName)
            }
            Button("取消", role: .cancel) {}
        }
        .alert("重命名分类", isPresented: renameBinding) {
            TextField("分类名称", text: $renameText)
            Button("保存") {
                if let categoryBeingRenamed {
                    store.renameCategory(id: categoryBeingRenamed.id, to: renameText)
                }
                categoryBeingRenamed = nil
            }
            Button("取消", role: .cancel) {
                categoryBeingRenamed = nil
            }
        }
        .overlay(alignment: .bottom) {
            if let dropFeedback {
                Text(dropFeedback)
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

    private var glassBackground: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()

            Rectangle()
                .fill(Color.black.opacity(0.18))
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.white.opacity(0.08),
                    Color.cyan.opacity(0.04),
                    Color.indigo.opacity(0.06),
                    Color.black.opacity(0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .blendMode(.softLight)

            Rectangle()
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                .ignoresSafeArea()
        }
    }

    private var topBar: some View {
        ZStack {
            HStack {
                Spacer()

                Button {
                    rescanApps()
                } label: {
                    if isRescanning {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .font(.title2)
                .disabled(isRescanning)
                .help("重新扫描应用")

            }

            HStack(spacing: 10) {
                TextField("搜索应用", text: $store.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 22, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.thinMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.24), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
                    .focused($searchFocused)
                    .frame(maxWidth: 520)

                if !store.query.isEmpty {
                    Button {
                        store.query = ""
                        searchFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .font(.title2)
                    .help("清空搜索")
                }
            }
        }
        .foregroundStyle(.primary)
        .frame(height: 54)
        .background(blankDismissArea)
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                sectionChip("全部", systemImage: "square.grid.3x3.fill", section: .all)
                sectionChip("收藏", systemImage: "star.fill", section: .favorites)
                    .dropTarget(.favorites)
                    .dropTargetHighlight(isActive: isActiveDropTarget(.favorites), label: "加入")
                    .dropDestination(for: String.self) { values, _ in
                        guard let dragID = values.first,
                              let appName = store.favoriteDraggedApp(dragID) else {
                            return false
                        }

                        showDropFeedback("已收藏“\(appName)”")
                        return true
                    }
                    .onDrop(
                        of: [UTType.text],
                        delegate: AppChipDropDelegate { dragID in
                            guard let appName = store.favoriteDraggedApp(dragID) else {
                                return false
                            }

                            showDropFeedback("已收藏“\(appName)”")
                            return true
                        }
                    )
                sectionChip("最近", systemImage: "clock.fill", section: .recent)
                sectionChip("未分类", systemImage: "tray.fill", section: .uncategorized)

                ForEach(store.sortedCategories) { category in
                    categoryChip(category)
                }

                sectionChip("隐藏", systemImage: "eye.slash.fill", section: .hidden)
                    .dropTarget(.hidden)
                    .dropTargetHighlight(isActive: isActiveDropTarget(.hidden), label: "隐藏")
                    .dropDestination(for: String.self) { values, _ in
                        guard let dragID = values.first,
                              let appName = store.hideDraggedApp(dragID) else {
                            return false
                        }

                        showDropFeedback("已隐藏“\(appName)”")
                        return true
                    }
                    .onDrop(
                        of: [UTType.text],
                        delegate: AppChipDropDelegate { dragID in
                            guard let appName = store.hideDraggedApp(dragID) else {
                                return false
                            }

                            showDropFeedback("已隐藏“\(appName)”")
                            return true
                        }
                    )

                Button {
                    newCategoryName = ""
                    isAddingCategory = true
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 32, height: 32)
                        .background(.thinMaterial, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        }
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .frame(width: 32, height: 32)
                .contentShape(Circle())
                .categoryControlFrame("add-category")
                .help("新建分类")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
        }
        .frame(height: 36)
        .background(blankDismissArea)
        .simultaneousGesture(categoryBlankDismissGesture)
    }

    private var blankDismissArea: some View {
        Color.black.opacity(0.001)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("launcherOverlay"))
                    .onEnded { value in
                        guard activeDrag == nil,
                              categoryDrag == nil,
                              isPrimaryClickOrReleased,
                              abs(value.translation.width) < 4,
                              abs(value.translation.height) < 4 else {
                            return
                        }

                        onClose()
                    }
            )
    }

    private var categoryBlankDismissGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("launcherOverlay"))
            .onEnded { value in
                guard activeDrag == nil,
                      categoryDrag == nil,
                      isPrimaryClickOrReleased,
                      abs(value.translation.width) < 4,
                      abs(value.translation.height) < 4,
                      !startsInsideCategoryControl(value.startLocation) else {
                    return
                }

                onClose()
            }
    }

    private var isPrimaryClickOrReleased: Bool {
        NSEvent.pressedMouseButtons == 0 || NSEvent.pressedMouseButtons & 1 == 1
    }

    private func startsInsideCategoryControl(_ location: CGPoint) -> Bool {
        categoryControlFrames.values.contains { frame in
            frame.insetBy(dx: -4, dy: -4).contains(location)
        }
    }

    @ViewBuilder
    private var categoryDragPreview: some View {
        if let categoryDrag {
            Label(categoryDrag.title, systemImage: "folder.fill")
                .font(.callout)
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.20), radius: 16, y: 8)
                .position(x: categoryDrag.location.x, y: categoryDrag.location.y - 26)
                .allowsHitTesting(false)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var dragPreview: some View {
        if let activeDrag {
            VStack(spacing: 7) {
                dragPreviewIcon(for: activeDrag)

                Text(activeDrag.title)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 112)

                Text(dragPreviewSubtitle(for: activeDrag))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.12), in: Capsule())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .frame(width: 132, height: 142)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.24), radius: 20, y: 10)
            .scaleEffect(1.04)
            .position(x: activeDrag.location.x, y: activeDrag.location.y - 48)
            .allowsHitTesting(false)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func dragPreviewIcon(for drag: LauncherDragState) -> some View {
        if let app = drag.entry?.app {
            Image(nsImage: iconCache.icon(for: app))
                .resizable()
                .frame(width: 64, height: 64)
                .cornerRadius(14)
        } else if drag.entry?.folder != nil {
            folderPreviewIcon(for: drag.entry)
        } else {
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 32, weight: .semibold))
                .frame(width: 64, height: 64)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func folderPreviewIcon(for entry: GridEntry?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
                .frame(width: 70, height: 70)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(22), spacing: 3), count: 2), spacing: 3) {
                ForEach(Array((entry?.folderApps ?? []).prefix(4))) { app in
                    Image(nsImage: iconCache.icon(for: app))
                        .resizable()
                        .frame(width: 22, height: 22)
                        .cornerRadius(5)
                }
            }
        }
    }

    private func dragPreviewSubtitle(for drag: LauncherDragState) -> String {
        guard LaunchDragID(rawValue: drag.dragID)?.isApp == true else {
            return drag.subtitle
        }

        if isActiveDropTarget(.favorites) {
            return "松手加入收藏"
        }

        if isActiveDropTarget(.hidden) {
            return "松手隐藏"
        }

        for category in store.sortedCategories where isActiveDropTarget(.category(category.id)) {
            return "松手加入“\(category.name)”"
        }

        return drag.subtitle
    }

    private var renameBinding: Binding<Bool> {
        Binding(
            get: { categoryBeingRenamed != nil },
            set: { if !$0 { categoryBeingRenamed = nil } }
        )
    }

    private func sectionChip(_ title: String, systemImage: String, section: LauncherSection) -> some View {
        Button {
            store.activeSection = section
            store.query = ""
        } label: {
            Label(title, systemImage: systemImage)
                .font(.callout)
                .fontWeight(store.activeSection == section ? .semibold : .medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(chipBackground(isSelected: store.activeSection == section), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(chipStroke(isSelected: store.activeSection == section), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .categoryControlFrame("section-\(title)")
    }

    private func categoryChip(_ category: LaunchCategory) -> some View {
        Button {
            store.activeSection = .category(category.id)
            store.query = ""
        } label: {
            Label(category.name, systemImage: "folder.fill")
                .font(.callout)
                .fontWeight(store.activeSection == .category(category.id) ? .semibold : .medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(chipBackground(isSelected: store.activeSection == .category(category.id)), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(chipStroke(isSelected: store.activeSection == .category(category.id)), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .categoryControlFrame("category-\(category.id)")
        .dropTarget(.category(category.id))
        .dropTargetHighlight(isActive: isActiveDropTarget(.category(category.id)), label: dropTargetLabel(for: category))
        .simultaneousGesture(categoryDragGesture(for: category))
        .contextMenu {
            Button("重命名") {
                categoryBeingRenamed = category
                renameText = category.name
            }
            Button("删除", role: .destructive) {
                store.deleteCategory(id: category.id)
            }
        }
        .dropDestination(for: String.self) { values, _ in
            guard let dragID = values.first,
                  let appName = store.addDraggedApp(dragID, toCategory: category.id) else {
                return false
            }

            showDropFeedback("已将“\(appName)”加入“\(category.name)”")
            return true
        }
        .onDrop(
            of: [UTType.text],
            delegate: AppChipDropDelegate { dragID in
                guard let appName = store.addDraggedApp(dragID, toCategory: category.id) else {
                    return false
                }

                showDropFeedback("已将“\(appName)”加入“\(category.name)”")
                return true
            }
        )
    }

    private func dropTargetLabel(for category: LaunchCategory) -> String {
        if categoryDrag != nil {
            return "排序"
        }
        return "加入"
    }

    private func isActiveDropTarget(_ target: LauncherDropTarget) -> Bool {
        guard let frame = dropTargetFrames[target] else {
            return false
        }

        if let activeDrag {
            return frame.insetBy(dx: -6, dy: -8).contains(activeDrag.location)
        }

        if let categoryDrag,
           case .category(let categoryID) = target,
           categoryID != categoryDrag.categoryID {
            return frame.insetBy(dx: -8, dy: -10).contains(categoryDrag.location)
        }

        return false
    }

    private func handleCustomDrop(dragID: String, at location: CGPoint) -> Bool {
        let expandedFrames = dropTargetFrames.mapValues { $0.insetBy(dx: -6, dy: -8) }

        if expandedFrames[.favorites]?.contains(location) == true,
           let appName = store.favoriteDraggedApp(dragID) {
            showDropFeedback("已收藏“\(appName)”")
            return true
        }

        if expandedFrames[.hidden]?.contains(location) == true,
           let appName = store.hideDraggedApp(dragID) {
            showDropFeedback("已隐藏“\(appName)”")
            return true
        }

        for category in store.sortedCategories {
            let target = LauncherDropTarget.category(category.id)
            guard expandedFrames[target]?.contains(location) == true else {
                continue
            }

            guard let appName = store.addDraggedApp(dragID, toCategory: category.id) else {
                return false
            }

            showDropFeedback("已将“\(appName)”加入“\(category.name)”")
            return true
        }

        return false
    }

    private func categoryDragGesture(for category: LaunchCategory) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named("launcherOverlay"))
            .onChanged { value in
                activeDrag = nil
                categoryDrag = CategoryDragState(
                    categoryID: category.id,
                    title: category.name,
                    location: value.location
                )
            }
            .onEnded { value in
                let draggedID = category.id
                categoryDrag = nil

                guard let destination = categoryDropDestination(for: draggedID, at: value.location) else {
                    return
                }

                withAnimation(.snappy(duration: 0.18)) {
                    store.moveCategory(id: draggedID, before: destination.targetID)
                }
                showDropFeedback("已调整分类顺序")
            }
    }

    private func categoryDropDestination(for draggedID: String, at location: CGPoint) -> CategoryDropDestination? {
        let expandedFrames = dropTargetFrames.mapValues { $0.insetBy(dx: -8, dy: -10) }

        for category in store.sortedCategories where category.id != draggedID {
            let target = LauncherDropTarget.category(category.id)
            if expandedFrames[target]?.contains(location) == true {
                return .before(category.id)
            }
        }

        guard let lastCategory = store.sortedCategories.last,
              lastCategory.id != draggedID,
              let lastFrame = expandedFrames[.category(lastCategory.id)],
              location.x > lastFrame.maxX,
              location.y >= lastFrame.minY,
              location.y <= lastFrame.maxY else {
            return nil
        }

        return .end
    }

    private func chipBackground(isSelected: Bool) -> Color {
        isSelected ? Color.accentColor.opacity(0.22) : Color.white.opacity(0.12)
    }

    private func chipStroke(isSelected: Bool) -> Color {
        isSelected ? Color.accentColor.opacity(0.38) : Color.white.opacity(0.12)
    }

    private func showDropFeedback(_ message: String) {
        withAnimation(.snappy(duration: 0.16)) {
            dropFeedback = message
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            guard dropFeedback == message else {
                return
            }

            withAnimation(.snappy(duration: 0.18)) {
                dropFeedback = nil
            }
        }
    }

    private func rescanApps() {
        guard !isRescanning else {
            return
        }

        isRescanning = true
        Task {
            let appCount = await store.rescanAsync()
            isRescanning = false
            showDropFeedback("已重新扫描，发现 \(appCount) 个应用")
        }
    }
}

private struct AppChipDropDelegate: DropDelegate {
    let onDrop: (String) -> Bool

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text])
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.text]).first else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            let value: String?
            if let data = item as? Data {
                value = String(data: data, encoding: .utf8)
            } else if let string = item as? NSString {
                value = string as String
            } else {
                value = item as? String
            }

            guard let value else {
                return
            }

            Task { @MainActor in
                _ = onDrop(value)
            }
        }

        return true
    }
}

private struct DropTargetFramePreferenceKey: PreferenceKey {
    static var defaultValue: [LauncherDropTarget: CGRect] = [:]

    static func reduce(
        value: inout [LauncherDropTarget: CGRect],
        nextValue: () -> [LauncherDropTarget: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct CategoryControlFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(
        value: inout [String: CGRect],
        nextValue: () -> [String: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private extension View {
    func dropTarget(_ target: LauncherDropTarget) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: DropTargetFramePreferenceKey.self,
                    value: [target: proxy.frame(in: .named("launcherOverlay"))]
                )
            }
        }
    }

    func categoryControlFrame(_ id: String) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: CategoryControlFramePreferenceKey.self,
                    value: [id: proxy.frame(in: .named("launcherOverlay"))]
                )
            }
        }
    }

    func dropTargetHighlight(isActive: Bool, label: String) -> some View {
        overlay {
            ZStack(alignment: .topTrailing) {
                Capsule()
                    .stroke(Color.accentColor.opacity(isActive ? 0.80 : 0), lineWidth: 2)
                    .shadow(color: Color.accentColor.opacity(isActive ? 0.36 : 0), radius: 12)

                if isActive {
                    Text(label)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor, in: Capsule())
                        .offset(x: 6, y: -7)
                        .transition(.scale(scale: 0.86).combined(with: .opacity))
                }
            }
        }
    }
}
