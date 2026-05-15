import Foundation

extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return String(dropFirst(prefix.count))
    }

    func trimmingSuffix(_ suffix: String) -> String {
        guard hasSuffix(suffix) else { return self }
        return String(dropLast(suffix.count))
    }

    func dropTrailingSlashes() -> Substring {
        var value = self[...]
        while value.hasSuffix("/") {
            value = value.dropLast()
        }
        return value
    }

    var urlPathEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? self
    }
}
