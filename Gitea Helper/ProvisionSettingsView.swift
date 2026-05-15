import SwiftUI

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
            Toggle("Add workstation number to repo names", isOn: $host.addWorkstationNumberToRepoName)
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
