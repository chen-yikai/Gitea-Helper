import SwiftUI
import SwiftData

enum AppError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case let .message(message):
            return message
        }
    }

}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GiteaHost.createdAt) private var hosts: [GiteaHost]
    @State private var selectedHost: GiteaHost?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedHost) {
                ForEach(hosts) { host in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(host.name).font(.headline)
                        Text(host.baseURL).font(.caption).foregroundStyle(.secondary)
                    }.tag(host)
                }.onDelete(perform: deleteHosts)
            }
            .navigationTitle("Hosts")
            .toolbar { Button(action: addHost) { Label("Add", systemImage: "plus") } }
        } detail: {
            if let selectedHost { HostDashboardView(host: selectedHost) }
            else { ContentUnavailableView("Add a Gitea host", systemImage: "server.rack") }
        }
        .onAppear { selectedHost = selectedHost ?? hosts.first }
    }

    private func addHost() {
        let host = GiteaHost(name: "New Host", baseURL: "https://gitea.example.com", adminToken: "")
        modelContext.insert(host)
        selectedHost = host
    }

    private func deleteHosts(offsets: IndexSet) {
        offsets.map { hosts[$0] }.forEach(modelContext.delete)
    }

}

struct HostDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var host: GiteaHost

    @State private var users: [String] = []
    @State private var repos: [String] = []
    @State private var newUser = ""
    @State private var newRepo = ""
    @State private var testRepoName = "my-test-project"
    @State private var testRepoDescription = ""
    @State private var readmeContent = "# My Test Project\n\nThis is a test repository."
    @State private var deleteOwner = ""
    @State private var deleteRepoName = ""
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
    @State private var showTestProjectSheet = false
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
                    Button("Configure") { showProvisionSheet = true }
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


                actionSection("Test Project") {
                    Button("Configure") { showTestProjectSheet = true }
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
        .sheet(isPresented: $showTestProjectSheet) {
            TestProjectSettingsView(
                testRepoName: $testRepoName,
                testRepoDescription: $testRepoDescription,
                readmeContent: $readmeContent,
                deleteOwner: $deleteOwner,
                deleteRepoName: $deleteRepoName,
                isWorking: isWorking,
                onCreate: { await createTestProject() },
                onRemove: { await deleteTestProject() }
            )
        }
        .task(id: host.id) {
            guard !hasLoadedRepositories else { return }
            hasLoadedRepositories = true
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

    private func createTestProject() async {
        await run("Creating test project...") {
            let fullName = try await api.createTestRepository(name: testRepoName, description: testRepoDescription, readme: readmeContent)
            let parts = fullName.split(separator: "/", maxSplits: 1).map(String.init)
            deleteOwner = parts.first ?? ""
            deleteRepoName = parts.count > 1 ? parts[1] : testRepoName
            statusMessage = "Created \(fullName)."
            await loadRepositories()
        }
    }

    private func deleteTestProject() async {
        await run("Removing test project...") {
            try await api.deleteRepository(owner: deleteOwner, name: deleteRepoName)
            statusMessage = "Removed \(deleteOwner)/\(deleteRepoName)."
            await loadRepositories()
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
        let digits = username.filter(\.isNumber)
        return digits.isEmpty ? base : base + String(digits.suffix(2))
    }

    private func password() -> String {
        String((0..<5).compactMap { _ in Array("abcdefghijklmnopqrstuvwxyz").randomElement() })
    }
}

struct ConnectionSettingsView: View {
    @Bindable var host: GiteaHost
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connection")
                .font(.title2.bold())
            TextField("Name", text: $host.name)
            TextField("Gitea URL", text: $host.baseURL)
            SecureField("Admin Token", text: $host.adminToken)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}


struct ProvisionSettingsView: View {
    @Bindable var host: GiteaHost
    @Binding var users: [String]
    @Binding var repos: [String]
    @Binding var newUser: String
    @Binding var newRepo: String
    let isWorking: Bool
    let onRunSetup: () async -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Provision")
                .font(.title2.bold())
            TextField("Email domain", text: $host.emailDomain)
            Text("Generated users will use username@\(displayDomain).")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                EditableNameList(title: "Users", items: $users, newValue: $newUser, placeholder: "s04")
                EditableNameList(title: "Repos", items: $repos, newValue: $newRepo, placeholder: "module-c")
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Done") {
                    Task {
                        await onRunSetup()
                        dismiss()
                    }
                }
                .disabled(isWorking)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 640)
    }

    private var displayDomain: String {
        let domain = host.emailDomain.trimmingCharacters(in: .whitespacesAndNewlines).trimmingPrefix("@")
        return domain.isEmpty ? "skills.edu" : domain
    }
}

struct TestProjectSettingsView: View {
    @Binding var testRepoName: String
    @Binding var testRepoDescription: String
    @Binding var readmeContent: String
    @Binding var deleteOwner: String
    @Binding var deleteRepoName: String
    let isWorking: Bool
    let onCreate: () async -> Void
    let onRemove: () async -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Test Project")
                .font(.title2.bold())
            TextField("Repository name", text: $testRepoName)
            TextField("Description", text: $testRepoDescription)
            TextEditor(text: $readmeContent)
                .frame(height: 90)
                .border(.quaternary)
            HStack {
                TextField("Owner", text: $deleteOwner)
                TextField("Repo", text: $deleteRepoName)
            }
            HStack {
                Spacer()
                Button("Create") {
                    Task { await onCreate() }
                }
                .disabled(isWorking)
                Button("Remove", role: .destructive) {
                    Task { await onRemove() }
                }
                .disabled(isWorking)
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}

struct EditableNameList: View {
    let title: String
    @Binding var items: [String]
    @Binding var newValue: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(items.count)").font(.caption).foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { index in
                    HStack {
                        TextField(placeholder, text: $items[index])
                            .textFieldStyle(.plain)
                        Button(role: .destructive) { items.remove(at: index) } label: {
                            Image(systemName: "minus.circle")
                        }.buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    if index != items.indices.last { Divider() }
                }
                HStack {
                    TextField(placeholder, text: $newValue)
                        .textFieldStyle(.plain)
                        .onSubmit(add)
                    Button(action: add) { Image(systemName: "plus.circle.fill") }.buttonStyle(.plain)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(.quaternary.opacity(0.35))
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(.quaternary) }
        }
    }

    private func add() {
        let value = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        items.append(value)
        newValue = ""
    }
}

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

private extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return String(dropFirst(prefix.count))
    }
    func dropTrailingSlashes() -> Substring {
        var value = self[...]
        while value.hasSuffix("/") {
            value = value.dropLast()
        }
        return value
    }
}

struct SimpleAccountRow: View {
    let account: GeneratedAccount
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            CopyableAccountField(value: account.username, width: 90, monospaced: true)
            CopyableAccountField(value: account.email, foregroundStyle: .secondary)
            CopyableAccountField(value: account.password, monospaced: true)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
        .contentShape(Rectangle())
        .onTapGesture {
            copyAccountInfo()
        }
    }

    private func copyAccountInfo() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("\(account.username)\n\(account.email)\n\(account.password)", forType: .string)
    }
}

struct CopyableAccountField: View {
    let value: String
    var width: CGFloat?
    var monospaced = false
    var foregroundStyle: Color = .primary

    var body: some View {
        HStack(spacing: 4) {
            Text(value)
                .font(monospaced ? .system(.body, design: .monospaced) : .body)
                .foregroundStyle(foregroundStyle)
                .lineLimit(1)
                .frame(width: width, alignment: .leading)
            Button {
                copyValue()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: width == nil ? .infinity : width.map { $0 + 22 }, alignment: .leading)
    }

    private func copyValue() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

#Preview { ContentView().modelContainer(for: [GiteaHost.self, GeneratedAccount.self], inMemory: true) }
