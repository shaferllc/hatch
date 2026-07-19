import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Hotkey
            HStack {
                Text("Open Hatch")
                    .font(.body.weight(.medium))
                Spacer()
                Text(HotKey.displayString)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                Text("(fixed in this version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Show hidden files by default", isOn: Binding(
                get: { store.showHiddenDefault },
                set: { store.showHiddenDefault = $0 }
            ))
            .help("⌘. toggles hidden files live inside the panel")

            Divider()

            section(title: "Pinned folders",
                    empty: "Nothing pinned yet — press ⌘D on a folder in the panel.",
                    paths: store.data.favorites,
                    remove: { store.removeFavorite($0) },
                    add: { store.addFavoritePath($0) },
                    addLabel: "Pin Folder…")

            Divider()

            section(title: "Extra roots",
                    empty: "Home, Desktop, Documents, Downloads and iCloud Drive are always shown.",
                    paths: store.data.extraRoots,
                    remove: { store.removeExtraRoot($0) },
                    add: { store.addExtraRoot($0) },
                    addLabel: "Add Root…")

            Text("Root and pin changes apply the next time the panel opens.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(width: 440)
    }

    @ViewBuilder
    private func section(title: String, empty: String, paths: [String],
                         remove: @escaping (String) -> Void,
                         add: @escaping (URL) -> Void,
                         addLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.body.weight(.medium))
            if paths.isEmpty {
                Text(empty)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(paths, id: \.self) { path in
                HStack(spacing: 6) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                        .resizable()
                        .frame(width: 14, height: 14)
                    Text((path as NSString).abbreviatingWithTildeInPath)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button {
                        remove(path)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            Button(addLabel) {
                pickFolder(then: add)
            }
            .controlSize(.small)
        }
    }

    private func pickFolder(then add: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            add(url)
        }
    }
}
