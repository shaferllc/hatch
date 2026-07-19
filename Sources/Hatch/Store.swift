import Foundation

struct SettingsData: Codable {
    var favorites: [String] = []
    var recents: [String] = []
    var extraRoots: [String] = []
    var showHiddenDefault: Bool = false
}

/// JSON persistence under ~/Library/Application Support/Hatch/settings.json.
@MainActor
final class Store: ObservableObject {
    @Published private(set) var data = SettingsData()

    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Hatch/settings.json")
    }

    init() {
        load()
    }

    func load() {
        guard let raw = try? Data(contentsOf: Self.fileURL),
              let decoded = try? JSONDecoder().decode(SettingsData.self, from: raw)
        else { return }
        data = decoded
    }

    func save() {
        let url = Self.fileURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let raw = try? encoder.encode(data) {
            try? raw.write(to: url, options: .atomic)
        }
    }

    // MARK: Favorites

    var favoriteURLs: [URL] {
        data.favorites.map { URL(fileURLWithPath: $0) }
    }

    func isFavorite(_ url: URL) -> Bool {
        data.favorites.contains(url.path)
    }

    func toggleFavorite(_ url: URL) {
        if let idx = data.favorites.firstIndex(of: url.path) {
            data.favorites.remove(at: idx)
        } else {
            data.favorites.append(url.path)
        }
        save()
    }

    func removeFavorite(_ path: String) {
        data.favorites.removeAll { $0 == path }
        save()
    }

    // MARK: Recents

    var recentURLs: [URL] {
        data.recents.map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    func addRecent(_ url: URL) {
        data.recents.removeAll { $0 == url.path }
        data.recents.insert(url.path, at: 0)
        if data.recents.count > 10 {
            data.recents.removeLast(data.recents.count - 10)
        }
        save()
    }

    // MARK: Roots

    func addExtraRoot(_ url: URL) {
        guard !data.extraRoots.contains(url.path) else { return }
        data.extraRoots.append(url.path)
        save()
    }

    func removeExtraRoot(_ path: String) {
        data.extraRoots.removeAll { $0 == path }
        save()
    }

    func addFavoritePath(_ url: URL) {
        guard !data.favorites.contains(url.path) else { return }
        data.favorites.append(url.path)
        save()
    }

    var showHiddenDefault: Bool {
        get { data.showHiddenDefault }
        set { data.showHiddenDefault = newValue; save() }
    }
}
