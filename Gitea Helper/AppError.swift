import Foundation

enum AppError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case let .message(message):
            return message
        }
    }
}
