import Foundation

public struct PlausibleAPIError: Decodable, Error, Sendable, Equatable {
    public let message: String
    public let fieldErrors: [String: [String]]?

    enum CodingKeys: String, CodingKey {
        case error
        case errors
    }

    public init(message: String, fieldErrors: [String: [String]]? = nil) {
        self.message = message
        self.fieldErrors = fieldErrors
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let message = try container.decodeIfPresent(String.self, forKey: .error) {
            self.init(message: message)
            return
        }

        let fieldErrors = try container.decode([String: [String]].self, forKey: .errors)
        let message = fieldErrors.keys.sorted().map { field in
            "\(field): \(fieldErrors[field, default: []].joined(separator: ", "))"
        }.joined(separator: "; ")
        self.init(message: message, fieldErrors: fieldErrors)
    }
}

public enum PlausibleTransportError: Error, Sendable, Equatable {
    case invalidURL(String)
    case invalidResponse
    case encodingFailure(String)
    case decodingFailure(String)
    case missingBody
    case unexpectedStatus(Int)
    case api(PlausibleAPIError, statusCode: Int)
}
