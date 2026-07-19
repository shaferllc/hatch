import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Panel root

struct PanelRootView: View {
    @ObservedObject var model: BrowserModel
    @ObservedObject var store: Store

    var body: some View {
        VStack(spacing: 0) {
            FavoritesStrip(model: model, store: store)
            Divider()
            ColumnsView(model: model)
            Divider()
            FooterView(model: model, store: store)
        }
        .frame(width: 760, height: 480)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Favorites strip

struct FavoritesStrip: View {
    @ObservedObject var model: BrowserModel
    @ObservedObject var store: Store

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if store.favoriteURLs.isEmpty {
                    Text("⌘D pins the selected folder here")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                ForEach(store.favoriteURLs, id: \.self) { url in
                    FavoriteChip(url: url, model: model, store: store)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(height: 32)
    }
}

struct FavoriteChip: View {
    let url: URL
    @ObservedObject var model: BrowserModel
    @ObservedObject var store: Store

    var body: some View {
        Button {
            model.jump(to: url)
        } label: {
            HStack(spacing: 4) {
                Image(nsImage: model.icon(for: url))
                    .resizable()
                    .frame(width: 14, height: 14)
                Text(url.lastPathComponent)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.07), in: Capsule())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Unpin") { store.removeFavorite(url.path) }
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }
}

// MARK: - Miller columns

struct ColumnsView: View {
    @ObservedObject var model: BrowserModel

    private let columnWidth: CGFloat = 252

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(model.columns.enumerated()), id: \.element.id) { index, column in
                        ColumnView(model: model, index: index)
                            .frame(width: columnWidth)
                            .id(column.id)
                        Divider()
                    }
                }
            }
            .onChange(of: model.columns.count) {
                scrollToActive(proxy)
            }
            .onChange(of: model.activeIndex) {
                scrollToActive(proxy)
            }
        }
    }

    private func scrollToActive(_ proxy: ScrollViewProxy) {
        // Keep the preview column (right of active) in view when it exists.
        let target = min(model.activeIndex + 1, model.columns.count - 1)
        guard target >= 0, target < model.columns.count else { return }
        withAnimation(.easeOut(duration: 0.12)) {
            proxy.scrollTo(model.columns[target].id, anchor: .trailing)
        }
    }
}

struct ColumnView: View {
    @ObservedObject var model: BrowserModel
    let index: Int

    var body: some View {
        if index < model.columns.count {
            let column = model.columns[index]
            let items = model.filteredItems(index)
            VStack(spacing: 0) {
                header(column)
                if items.isEmpty {
                    Spacer()
                    Text(column.filter.isEmpty ? "Empty folder" : "No matches")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 1) {
                                ForEach(Array(items.enumerated()), id: \.element.id) { row, item in
                                    if showsHeader(items: items, row: row) {
                                        Text(item.group ?? "")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                            .textCase(.uppercase)
                                            .padding(.horizontal, 10)
                                            .padding(.top, row == 0 ? 4 : 10)
                                            .padding(.bottom, 2)
                                    }
                                    RowView(model: model, item: item,
                                            selected: row == column.selection,
                                            active: index == model.activeIndex)
                                        .id(item.id)
                                        .onTapGesture(count: 2) {
                                            model.select(column: index, row: row)
                                            model.openSelection()
                                        }
                                        .onTapGesture {
                                            model.select(column: index, row: row)
                                        }
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                        }
                        .onChange(of: column.selection) {
                            scrollToSelection(proxy, items: items, selection: column.selection)
                        }
                        .onAppear {
                            scrollToSelection(proxy, items: items, selection: column.selection)
                        }
                    }
                }
            }
        }
    }

    private func showsHeader(items: [FileItem], row: Int) -> Bool {
        guard let group = items[row].group else { return false }
        if row == 0 { return true }
        return items[row - 1].group != group
    }

    private func scrollToSelection(_ proxy: ScrollViewProxy, items: [FileItem], selection: Int) {
        guard selection >= 0, selection < items.count else { return }
        proxy.scrollTo(items[selection].id)
    }

    @ViewBuilder
    private func header(_ column: BrowserModel.Column) -> some View {
        HStack(spacing: 6) {
            Text(column.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if !column.filter.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 8))
                    Text(column.filter)
                        .font(.caption2)
                        .lineLimit(1)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.2), in: Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }
}

// MARK: - Row

struct RowView: View {
    @ObservedObject var model: BrowserModel
    let item: FileItem
    let selected: Bool
    let active: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(nsImage: model.icon(for: item.url))
                .resizable()
                .frame(width: 16, height: 16)
            Text(item.name)
                .font(.system(size: 12.5))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            if item.isDirectory {
                if let count = model.childCounts[item.url] {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundStyle(selected && active ? .white.opacity(0.75) : Color.secondary)
                        .monospacedDigit()
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(selected && active ? .white.opacity(0.75) : Color.secondary)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(
            selected
                ? (active ? Color.accentColor : Color.secondary.opacity(0.22))
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
        )
        .foregroundStyle(selected && active ? Color.white : Color.primary)
        .contentShape(Rectangle())
        .onDrag {
            NSItemProvider(object: item.url as NSURL)
        }
    }
}

// MARK: - Footer

struct FooterView: View {
    @ObservedObject var model: BrowserModel
    @ObservedObject var store: Store

    var body: some View {
        HStack(spacing: 8) {
            if let item = model.selectedItem {
                Image(nsImage: model.icon(for: item.url))
                    .resizable()
                    .frame(width: 16, height: 16)
                Text(item.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if store.isFavorite(item.url) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange)
                }
                Text(model.footerInfo(for: item))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("No selection")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 12)
            Text("⏎ Open   ⌘⏎ Reveal   ␣ Peek   ⌘D Pin   ⌘C Copy   ⌘. \(model.showHidden ? "Hide" : "Show") Hidden")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .layoutPriority(-1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
}
