import SwiftUI

struct SimpleRepoRow: View {
    let repo: GiteaRepository
    let hostBaseURL: String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                openRepository()
            } label: {
                HStack(spacing: 10) {
                Image(systemName: repo.isPrivate ? "lock" : "folder")
                    .foregroundStyle(repo.isPrivate ? .orange : .blue)
                    .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(repo.fullName).font(.system(.body, design: .monospaced)).lineLimit(1)
                        if let description = repo.description, !description.isEmpty {
                            Text(description).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .buttonStyle(.plain)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
    }

    private func openRepository() {
        guard let url = repositoryURL else { return }
        NSWorkspace.shared.open(url)
    }

    private var repositoryURL: URL? {
        let trimmedBaseURL = String(hostBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).dropTrailingSlashes())
        guard !trimmedBaseURL.isEmpty else { return nil }

        let ownerName = repo.owner?.username ?? repo.fullName.split(separator: "/", maxSplits: 1).first.map(String.init)
        guard let ownerName else { return URL(string: trimmedBaseURL + "/" + repo.fullName) }

        return URL(string: trimmedBaseURL + "/" + ownerName + "/" + repo.name)
    }
}
