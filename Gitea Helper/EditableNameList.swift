import SwiftUI

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
