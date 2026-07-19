import AppKit
import Foundation

// MARK: - FileItem

struct FileItem: Identifiable, Hashable, Sendable {
    let url: URL
    let name: String
    let isDirectory: Bool     // true only for real (browsable) directories, not packages
    let group: String?        // section label in the virtual roots column

    var id: String { (group ?? "") + "|" + url.path }

    /// Loads a real directory's children, dirs first, alphabetical.
    nonisolated static func loadDirectory(_ url: URL, showHidden: Bool) -> [FileItem] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
        let options: FileManager.DirectoryEnumerationOptions = showHidden ? [] : [.skipsHiddenFiles]
        guard let children = try? fm.contentsOfDirectory(
            at: url, includingPropertiesForKeys: keys, options: options)
        else { return [] }
        var items = children.map { child -> FileItem in
            let values = try? child.resourceValues(forKeys: Set(keys))
            let isDir = (values?.isDirectory ?? false) && !(values?.isPackage ?? false)
            return FileItem(url: child, name: child.lastPathComponent,
                            isDirectory: isDir, group: nil)
        }
        items.sort { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
        return items
    }
}

// MARK: - BrowserModel

@MainActor
final class BrowserModel: ObservableObject {

    struct Column: Identifiable {
        let id = UUID()
        var title: String
        var url: URL?             // nil for the virtual roots column
        var items: [FileItem]
        var filter: String = ""
        var selection: Int = 0    // index into filteredItems
    }

    @Published var columns: [Column] = []
    @Published var activeIndex = 0
    @Published var showHidden: Bool
    @Published var childCounts: [URL: Int] = [:]

    let store: Store

    /// Set by the panel controller; called to dismiss the panel.
    var dismiss: (() -> Void)?
    /// Called whenever the selection changes (Quick Look refresh).
    var onSelectionChanged: (() -> Void)?

    private var iconCache: [URL: NSImage] = [:]

    init(store: Store) {
        self.store = store
        self.showHidden = store.showHiddenDefault
    }

    // MARK: Setup

    /// Fresh navigation state; called every time the panel is shown.
    func reset() {
        columns = [rootColumn()]
        activeIndex = 0
        syncPreview()
    }

    private func rootColumn() -> Column {
        var items: [FileItem] = []
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        var places: [(String, URL)] = [("Home", home)]
        for sub in ["Desktop", "Documents", "Downloads"] {
            let url = home.appendingPathComponent(sub)
            if fm.fileExists(atPath: url.path) { places.append((sub, url)) }
        }
        let icloud = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        if fm.fileExists(atPath: icloud.path) { places.append(("iCloud Drive", icloud)) }
        for path in store.data.extraRoots {
            let url = URL(fileURLWithPath: path)
            if fm.fileExists(atPath: url.path) { places.append((url.lastPathComponent, url)) }
        }
        for (name, url) in places {
            items.append(FileItem(url: url, name: name, isDirectory: true, group: "Places"))
        }
        for url in store.recentURLs {
            var isDir: ObjCBool = false
            fm.fileExists(atPath: url.path, isDirectory: &isDir)
            let values = try? url.resourceValues(forKeys: [.isPackageKey])
            let browsable = isDir.boolValue && !(values?.isPackage ?? false)
            items.append(FileItem(url: url, name: url.lastPathComponent,
                                  isDirectory: browsable, group: "Recents"))
        }
        return Column(title: "Hatch", url: nil, items: items)
    }

    private func makeColumn(for url: URL) -> Column {
        let items = FileItem.loadDirectory(url, showHidden: showHidden)
        computeCounts(for: items)
        return Column(title: url.lastPathComponent, url: url, items: items)
    }

    // MARK: Filtering

    /// Fuzzy prefix match: prefix hits rank first, then substring, then subsequence.
    nonisolated private static func matchRank(_ name: String, _ pattern: String) -> Int? {
        guard !pattern.isEmpty else { return 0 }
        let n = name.lowercased()
        let p = pattern.lowercased()
        if n.hasPrefix(p) { return 0 }
        if n.contains(p) { return 1 }
        // subsequence
        var it = n.startIndex
        for ch in p {
            guard let found = n[it...].firstIndex(of: ch) else { return nil }
            it = n.index(after: found)
        }
        return 2
    }

    func filteredItems(_ index: Int) -> [FileItem] {
        guard index < columns.count else { return [] }
        let col = columns[index]
        guard !col.filter.isEmpty else { return col.items }
        return col.items
            .enumerated()
            .compactMap { (offset, item) -> (Int, Int, FileItem)? in
                guard let rank = Self.matchRank(item.name, col.filter) else { return nil }
                return (rank, offset, item)
            }
            .sorted { ($0.0, $0.1) < ($1.0, $1.1) }
            .map { $0.2 }
    }

    var activeFilter: String {
        guard activeIndex < columns.count else { return "" }
        return columns[activeIndex].filter
    }

    // MARK: Selection

    func selectedItem(in index: Int) -> FileItem? {
        let items = filteredItems(index)
        guard index < columns.count,
              columns[index].selection >= 0,
              columns[index].selection < items.count else { return nil }
        return items[columns[index].selection]
    }

    var selectedItem: FileItem? { selectedItem(in: activeIndex) }

    /// Rebuilds the preview column to the right of the active selection.
    func syncPreview() {
        guard activeIndex < columns.count else { return }
        let desired: URL? = {
            guard let sel = selectedItem, sel.isDirectory else { return nil }
            return sel.url
        }()
        // Already showing the right preview?
        if let desired,
           columns.count == activeIndex + 2,
           columns[activeIndex + 1].url == desired {
            return
        }
        columns = Array(columns.prefix(activeIndex + 1))
        if let desired {
            columns.append(makeColumn(for: desired))
        }
    }

    func select(column: Int, row: Int) {
        guard column < columns.count else { return }
        activeIndex = column
        columns[column].selection = row
        syncPreview()
        onSelectionChanged?()
    }

    func move(_ delta: Int) {
        guard activeIndex < columns.count else { return }
        let count = filteredItems(activeIndex).count
        guard count > 0 else { return }
        let next = min(max(columns[activeIndex].selection + delta, 0), count - 1)
        guard next != columns[activeIndex].selection else { return }
        columns[activeIndex].selection = next
        syncPreview()
        onSelectionChanged?()
    }

    func descend() {
        guard let sel = selectedItem, sel.isDirectory,
              columns.count > activeIndex + 1 else { return }
        activeIndex += 1
        columns[activeIndex].selection = 0
        syncPreview()
        onSelectionChanged?()
    }

    func back() {
        guard activeIndex > 0 else { return }
        // Drop the deeper column's filter so returning is predictable.
        columns[activeIndex].filter = ""
        activeIndex -= 1
        syncPreview()
        onSelectionChanged?()
    }

    /// Jump straight to a pinned folder: roots column + that folder.
    func jump(to url: URL) {
        columns = [rootColumn(), makeColumn(for: url)]
        activeIndex = 1
        syncPreview()
        onSelectionChanged?()
    }

    // MARK: Type-to-filter

    func appendFilter(_ text: String) {
        guard activeIndex < columns.count else { return }
        columns[activeIndex].filter += text
        columns[activeIndex].selection = 0
        syncPreview()
        onSelectionChanged?()
    }

    func backspaceFilter() {
        guard activeIndex < columns.count, !columns[activeIndex].filter.isEmpty else { return }
        columns[activeIndex].filter.removeLast()
        columns[activeIndex].selection = 0
        syncPreview()
        onSelectionChanged?()
    }

    func clearFilter() {
        guard activeIndex < columns.count else { return }
        columns[activeIndex].filter = ""
        columns[activeIndex].selection = 0
        syncPreview()
        onSelectionChanged?()
    }

    // MARK: Actions

    func openSelection() {
        guard let sel = selectedItem else { return }
        store.addRecent(sel.url)
        NSWorkspace.shared.open(sel.url)
        dismiss?()
    }

    func revealSelection() {
        guard let sel = selectedItem else { return }
        store.addRecent(sel.url)
        NSWorkspace.shared.activateFileViewerSelecting([sel.url])
        dismiss?()
    }

    func copySelection() {
        guard let sel = selectedItem else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([sel.url as NSURL])
    }

    func toggleFavoriteSelection() {
        guard let sel = selectedItem else { return }
        guard sel.isDirectory else { NSSound.beep(); return }
        store.toggleFavorite(sel.url)
    }

    func toggleHidden() {
        showHidden.toggle()
        // Reload every real column in place; clamp selections.
        for i in columns.indices {
            if let url = columns[i].url {
                columns[i].items = FileItem.loadDirectory(url, showHidden: showHidden)
                computeCounts(for: columns[i].items)
            } else {
                columns[i].items = rootColumn().items
            }
            let count = filteredItems(i).count
            columns[i].selection = min(columns[i].selection, max(count - 1, 0))
        }
        syncPreview()
        onSelectionChanged?()
    }

    // MARK: Metadata

    func icon(for url: URL) -> NSImage {
        if let cached = iconCache[url] { return cached }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        iconCache[url] = image
        return image
    }

    /// Async child counts for the directories in a freshly loaded column.
    private func computeCounts(for items: [FileItem]) {
        let dirs = items.filter(\.isDirectory).map(\.url).filter { childCounts[$0] == nil }
        guard !dirs.isEmpty else { return }
        let hidden = showHidden
        Task.detached(priority: .utility) {
            var result: [URL: Int] = [:]
            let options: FileManager.DirectoryEnumerationOptions = hidden ? [] : [.skipsHiddenFiles]
            for url in dirs.prefix(400) {
                let count = (try? FileManager.default.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: nil, options: options).count) ?? 0
                result[url] = count
            }
            let final = result
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.childCounts.merge(final) { _, new in new }
            }
        }
    }

    /// Synchronous count for the footer (single directory, cached).
    func ensuredChildCount(for url: URL) -> Int? {
        if let cached = childCounts[url] { return cached }
        let options: FileManager.DirectoryEnumerationOptions = showHidden ? [] : [.skipsHiddenFiles]
        guard let count = try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil, options: options).count else { return nil }
        childCounts[url] = count
        return count
    }

    func footerInfo(for item: FileItem) -> String {
        var parts: [String] = []
        if item.isDirectory {
            if let count = ensuredChildCount(for: item.url) {
                parts.append("\(count) item\(count == 1 ? "" : "s")")
            }
        } else {
            let values = try? item.url.resourceValues(forKeys: [.fileSizeKey])
            if let size = values?.fileSize {
                parts.append(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
            }
        }
        let values = try? item.url.resourceValues(forKeys: [.contentModificationDateKey])
        if let date = values?.contentModificationDate {
            parts.append("Modified " + date.formatted(date: .abbreviated, time: .shortened))
        }
        return parts.joined(separator: "  ·  ")
    }
}
