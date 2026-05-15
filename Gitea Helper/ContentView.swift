import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GiteaHost.createdAt) private var hosts: [GiteaHost]
    @State private var selectedHost: GiteaHost?
    @State private var hostToDelete: GiteaHost?
    @State private var confirmHostDelete = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedHost) {
                ForEach(hosts) { host in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(host.name).font(.headline)
                            Text(host.baseURL).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            hostToDelete = host
                            confirmHostDelete = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .tag(host)
                }.onDelete(perform: deleteHosts)
            }
            .navigationTitle("Hosts")
            .toolbar { Button(action: addHost) { Label("Add", systemImage: "plus") } }
        } detail: {
            if let selectedHost { HostDashboardView(host: selectedHost) }
            else { ContentUnavailableView("Add a Gitea host", systemImage: "server.rack") }
        }
        .onAppear { selectedHost = selectedHost ?? hosts.first }
        .confirmationDialog("Delete this host?", isPresented: $confirmHostDelete) {
            Button("Delete host", role: .destructive) { deleteSelectedHost() }
        } message: {
            Text(hostToDelete?.name ?? "")
        }
    }

    private func addHost() {
        let host = GiteaHost(name: "New Host", baseURL: "", adminToken: "")
        modelContext.insert(host)
        selectedHost = host
    }

    private func deleteHosts(offsets: IndexSet) {
        offsets.map { hosts[$0] }.forEach(deleteHost)
    }

    private func deleteSelectedHost() {
        guard let hostToDelete else { return }
        deleteHost(hostToDelete)
        self.hostToDelete = nil
        confirmHostDelete = false
    }

    private func deleteHost(_ host: GiteaHost) {
        if selectedHost == host {
            selectedHost = hosts.first { $0 != host }
        }
        modelContext.delete(host)
    }
}

#Preview { ContentView().modelContainer(for: [GiteaHost.self, GeneratedAccount.self], inMemory: true) }
