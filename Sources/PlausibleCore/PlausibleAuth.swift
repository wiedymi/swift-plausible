import Foundation

public enum PlausibleAuth: Sendable, Equatable {
    case none
    case apiKey(String)

    func apply(to request: inout URLRequest) {
        switch self {
        case .none:
            break
        case .apiKey(let key):
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
    }
}
