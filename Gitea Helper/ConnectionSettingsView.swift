import SwiftUI

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
