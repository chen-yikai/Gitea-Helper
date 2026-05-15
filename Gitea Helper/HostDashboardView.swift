import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct HostDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var host: GiteaHost

    @State private var users: [String] = []
    @State private var repos: [String] = []
    @State private var newUser = ""
    @State private var newRepo = ""
    @State private var repositories: [GiteaRepository] = []
    @State private var statusMessage = "Ready."
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var isWorking = false
    @State private var confirmCleanup = false
    @State private var confirmRepoDelete = false
    @State private var confirmAccountDelete = false
    @State private var repoToDelete: GiteaRepository?
    @State private var accountToDelete: GeneratedAccount?
    @State private var showConnectionSheet = false
    @State private var showProvisionSheet = false
    @State private var showProvisioning = true
    @State private var showRepositories = true
    @State private var hasLoadedRepositories = false
    @State private var connectionTestSucceeded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if isWorking { ProgressView().controlSize(.small) }
                actionSection("Connection") {
                    HStack {
                        Text(hostDisplayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Button {
                            Task { await testConnection() }
                        } label: {
                            Image(systemName: connectionTestSucceeded ? "checkmark.circle.fill" : "network")
                                .foregroundStyle(connectionTestSucceeded ? .green : .primary)
                        }
                        .buttonStyle(.plain)
                        .disabled(isWorking)
                        Button("Configure") { showConnectionSheet = true }
                    }
                }


                compactSection("Provision", isExpanded: $showProvisioning) {
                    HStack {
                        Button {
                            exportProvisionCSV()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .buttonStyle(.plain)
                        .disabled(host.accounts.isEmpty)
                        Button("Configure") { showProvisionSheet = true }
                    }
                } content: {
                    if host.accounts.isEmpty {
                        Text("No generated accounts yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(sortedAccounts) { account in
                                SimpleAccountRow(account: account) {
                                    accountToDelete = account
                                    confirmAccountDelete = true
                                }
                                if account.id != sortedAccounts.last?.id { Divider() }
                            }
                        }
                        .overlay { RoundedRectangle(cornerRadius: 8).stroke(.quaternary) }
                    }
                    Text("\(users.count) users · \(repos.count) repos · \(host.accounts.count) saved accounts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }


                compactSection("Repositories", isExpanded: $showRepositories) {
                    Button {
                        Task { await loadRepositories() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)
                } content: {
                    if repositories.isEmpty {
                        Text("No repositories loaded.").foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(repositories) { repo in
                                SimpleRepoRow(repo: repo, hostBaseURL: host.baseURL) {
                                    repoToDelete = repo
                                    confirmRepoDelete = true
                                }
                                if repo.id != repositories.last?.id { Divider() }
                            }
                        }.overlay { RoundedRectangle(cornerRadius: 8).stroke(.quaternary) }
                    }
                    Text("\(repositories.count) loaded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                dangerSection("Danger Zone") {
                    Button("Clean Up", role: .destructive) { confirmCleanup = true }.disabled(isWorking)
                }
            }
            .padding(20)
            .frame(maxWidth: 880, alignment: .leading)
        }
        .navigationTitle(host.name)
        .navigationSubtitle(hostDisplayName)
        .toolbar {
            Button("Open Host", systemImage: "arrow.up.right.square") {
                openHost()
            }
            .disabled(URL(string: host.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)) == nil)
        }
        .confirmationDialog("Delete all non-admin users?", isPresented: $confirmCleanup) {
            Button("Delete non-admin users", role: .destructive) { Task { await cleanupUsers() } }
        }
        .confirmationDialog("Delete this repository?", isPresented: $confirmRepoDelete) {
            Button("Delete repository", role: .destructive) {
                Task { await deleteSelectedRepository() }
            }
        } message: {
            Text(repoToDelete?.fullName ?? "")
        }
        .confirmationDialog("Delete this user?", isPresented: $confirmAccountDelete) {
            Button("Delete user", role: .destructive) {
                Task { await deleteSelectedAccount() }
            }
        } message: {
            Text(accountToDelete?.username ?? "")
        }
        .alert("Something went wrong", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showConnectionSheet) {
            ConnectionSettingsView(host: host)
        }
        .sheet(isPresented: $showProvisionSheet) {
            ProvisionSettingsView(host: host, users: $users, repos: $repos, newUser: $newUser, newRepo: $newRepo, isWorking: isWorking) {
                await provision()
            }
        }
        .task(id: host.id) {
            guard !hasLoadedRepositories else { return }
            hasLoadedRepositories = true
            guard isConnectionConfigured else {
                showConnectionSheet = true
                return
            }
            await testConnection()
            await loadRepositories()
        }
        .onChange(of: host.baseURL) { _, _ in
            connectionTestSucceeded = false
        }
        .onChange(of: host.adminToken) { _, _ in
            connectionTestSucceeded = false
        }
    }

    private var api: GiteaAPI { GiteaAPI(baseURL: host.baseURL, token: host.adminToken) }
    private var sortedAccounts: [GeneratedAccount] {
        host.accounts.sorted { $0.username < $1.username }
    }
    private var emailDomain: String {
        let domain = host.emailDomain.trimmingCharacters(in: .whitespacesAndNewlines).trimmingPrefix("@")
        return domain.isEmpty ? "skills.edu" : domain
    }

    private var isConnectionConfigured: Bool {
        !host.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !host.adminToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hostDisplayName: String {
        let trimmedURL = host.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmedURL), let urlHost = url.host {
            return urlHost
        }
        return host.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func compactSection<Content: View>(_ title: String, isExpanded: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        compactSection(title, detail: nil, isExpanded: isExpanded) {
            EmptyView()
        } content: {
            content()
        }
    }

    private func compactSection<Content: View>(_ title: String, detail: String?, isExpanded: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        compactSection(title, detail: detail, isExpanded: isExpanded) {
            EmptyView()
        } content: {
            content()
        }
    }

    private func compactSection<Action: View, Content: View>(_ title: String, isExpanded: Binding<Bool>, @ViewBuilder action: () -> Action, @ViewBuilder content: @escaping () -> Content) -> some View {
        compactSection(title, detail: nil, isExpanded: isExpanded, action: action, content: content)
    }

    private func compactSection<Action: View, Content: View>(_ title: String, detail: String?, isExpanded: Binding<Bool>, @ViewBuilder action: () -> Action, @ViewBuilder content: @escaping () -> Content) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            VStack(alignment: .leading, spacing: 10) { content() }
                .padding(.top, 10)
        } label: {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if let detail, !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                action()
            }
        }
        .padding(12)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(.quaternary) }
        .animation(.easeOut(duration: 0.12), value: isExpanded.wrappedValue)
    }

    private func actionSection<Content: View>(_ title: String, @ViewBuilder action: () -> Content) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            action()
        }
        .padding(12)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(.quaternary) }
    }

    private func dangerSection<Content: View>(_ title: String, @ViewBuilder action: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.red)
            Spacer()
            action()
        }
        .padding(12)
        .background(.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(.red.opacity(0.35)) }
    }

    private func provision() async {
        await run("Provisioning users and repositories...") {
            let pendingUser = newUser.trimmingCharacters(in: .whitespacesAndNewlines)
            let pendingRepo = newRepo.trimmingCharacters(in: .whitespacesAndNewlines)
            let provisionUsers = users + (pendingUser.isEmpty ? [] : [pendingUser])
            let provisionRepos = repos + (pendingRepo.isEmpty ? [] : [pendingRepo])
            guard !host.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !host.adminToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !provisionUsers.isEmpty, !provisionRepos.isEmpty else { throw AppError.message("Please fill in the connection, users, and repos.") }
            for username in provisionUsers {
                let email = "\(username)@\(emailDomain)"
                let password = password()
                try await api.createUser(username: username, email: email, password: password)
                modelContext.insert(GeneratedAccount(username: username, email: email, password: password, host: host))
                for repo in provisionRepos { try await api.createRepository(for: username, name: repoName(repo, username)) }
            }
            try modelContext.save()
            users = []
            repos = []
            newUser = ""
            newRepo = ""
            statusMessage = "Created \(provisionUsers.count) users and \(provisionUsers.count * provisionRepos.count) repositories."
            await loadRepositories()
        }
    }

    private func deleteSelectedAccount() async {
        guard let account = accountToDelete else { return }
        accountToDelete = nil
        confirmAccountDelete = false
        await run("Deleting user...") {
            try await api.deleteUser(username: account.username)
            modelContext.delete(account)
            try modelContext.save()
            statusMessage = "Deleted \(account.username)."
            await loadRepositories()
        }
    }

    private func exportProvisionCSV() {
        let accounts = sortedAccounts
        guard !accounts.isEmpty else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "\(safeFileName(host.name))-provision.csv"

        guard savePanel.runModal() == .OK, let url = savePanel.url else { return }

        do {
            try provisionCSV(for: accounts).write(to: url, atomically: true, encoding: .utf8)
            statusMessage = "Exported \(accounts.count) accounts."
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func provisionCSV(for accounts: [GeneratedAccount]) -> String {
        let rows = accounts.map { account in
            [host.baseURL, account.username, account.email, account.password].map(csvValue).joined(separator: ",")
        }
        return (["host,username,email,password"] + rows).joined(separator: "\n") + "\n"
    }

    private func csvValue(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        guard escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") || escaped.contains("\r") else {
            return escaped
        }
        return "\"\(escaped)\""
    }

    private func safeFileName(_ value: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let parts = value.components(separatedBy: invalidCharacters)
        let fileName = parts.joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        return fileName.isEmpty ? "gitea-helper" : fileName
    }

    private func openHost() {
        guard let url = URL(string: host.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        NSWorkspace.shared.open(url)
    }

    private func testConnection() async {
        connectionTestSucceeded = false
        await run("Testing connection...") {
            let user = try await api.currentUser()
            statusMessage = "Connected as \(user.username)."
            connectionTestSucceeded = true
        }
    }

    private func deleteSelectedRepository() async {
        guard let repo = repoToDelete else { return }
        repoToDelete = nil
        confirmRepoDelete = false
        await run("Deleting repository...") {
            let ownerName = repo.owner?.username ?? repo.fullName.split(separator: "/", maxSplits: 1).first.map(String.init)
            guard let ownerName else { throw AppError.message("Could not find the repository owner.") }
            try await api.deleteRepository(owner: ownerName, name: repo.name)
            statusMessage = "Deleted \(ownerName)/\(repo.name)."
            await loadRepositories()
        }
    }

    private func loadRepositories() async {
        await run("Loading repositories...") {
            repositories = try await api.repositories()
            statusMessage = "Loaded \(repositories.count) repositories."
        }
    }

    private func cleanupUsers() async {
        await run("Cleaning up non-admin users...") {
            let removableUsers = try await api.users().filter { $0.isAdmin != true }
            for user in removableUsers { try await api.deleteUser(username: user.username) }
            for account in host.accounts {
                modelContext.delete(account)
            }
            try modelContext.save()
            users = []
            repos = []
            newUser = ""
            newRepo = ""
            statusMessage = "Deleted \(removableUsers.count) non-admin users."
        }
    }

    private func run(_ message: String, operation: () async throws -> Void) async {
        isWorking = true
        statusMessage = message
        defer { isWorking = false }
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func repoName(_ base: String, _ username: String) -> String {
        guard host.addWorkstationNumberToRepoName else { return base }
        let digits = username.filter(\.isNumber)
        return digits.isEmpty ? base : base + String(digits.suffix(2))
    }

    private func password() -> String {
        String((0..<5).compactMap { _ in Array("abcdefghijklmnopqrstuvwxyz").randomElement() })
    }
}
