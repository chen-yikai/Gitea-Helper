import SwiftUI
import AppKit

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
