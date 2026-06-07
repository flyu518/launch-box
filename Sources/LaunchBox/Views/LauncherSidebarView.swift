import LaunchBoxCore
import SwiftUI

struct LauncherSidebarView: View {
    @ObservedObject var store: LaunchStore
    let onCollapse: () -> Void

    @State private var isAddingCategory = false
    @State private var newCategoryName = ""
    @State private var categoryBeingRenamed: LaunchCategory?
    @State private var renameText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("启动台")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: onCollapse) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.borderless)
                .font(.title3)
                .foregroundStyle(.secondary)
                .help("隐藏分类")
            }

            VStack(alignment: .leading, spacing: 8) {
                sidebarButton("全部", systemImage: "square.grid.3x3.fill", section: .all)
                sidebarButton("收藏", systemImage: "star.fill", section: .favorites)
                sidebarButton("最近", systemImage: "clock.fill", section: .recent)
                sidebarButton("未分类", systemImage: "tray.fill", section: .uncategorized)
                sidebarButton("隐藏", systemImage: "eye.slash.fill", section: .hidden)
            }

            Divider()

            HStack {
                Text("分类")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    newCategoryName = ""
                    isAddingCategory = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .help("添加分类")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(store.sortedCategories) { category in
                        categoryButton(category)
                    }
                }
            }

            Spacer()

            if let warning = store.warning {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 8)
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
    }

    private var renameBinding: Binding<Bool> {
        Binding(
            get: { categoryBeingRenamed != nil },
            set: { if !$0 { categoryBeingRenamed = nil } }
        )
    }

    private func sidebarButton(_ title: String, systemImage: String, section: LauncherSection) -> some View {
        Button {
            store.activeSection = section
            store.query = ""
        } label: {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer(minLength: 0)
            }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(selectionColor(section), in: RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func categoryButton(_ category: LaunchCategory) -> some View {
        Button {
            store.activeSection = .category(category.id)
            store.query = ""
        } label: {
            HStack {
                Label(category.name, systemImage: "folder.fill")
                Spacer(minLength: 0)
            }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(selectionColor(.category(category.id)), in: RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("重命名") {
                categoryBeingRenamed = category
                renameText = category.name
            }
            Button("删除", role: .destructive) {
                store.deleteCategory(id: category.id)
            }
        }
    }

    private func selectionColor(_ section: LauncherSection) -> Color {
        store.activeSection == section ? Color.white.opacity(0.24) : Color.clear
    }
}
