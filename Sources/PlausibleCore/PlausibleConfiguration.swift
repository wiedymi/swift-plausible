import Foundation

public struct PlausibleConfiguration: Sendable {
    public var baseURL: URL
    public var userAgent: String?
    public var executor: PlausibleHTTPExecutor
    public var decoderFactory: @Sendable () -> JSONDecoder
    public var encoderFactory: @Sendable () -> JSONEncoder

    public init(
        baseURL: URL = URL(string: "https://plausible.io")!,
        userAgent: String? = nil,
        executor: PlausibleHTTPExecutor = .urlSession(.shared),
        decoderFactory: @escaping @Sendable () -> JSONDecoder = { JSONDecoder.plausibleDefault() },
        encoderFactory: @escaping @Sendable () -> JSONEncoder = { JSONEncoder.plausibleDefault() }
    ) {
        self.baseURL = baseURL
        self.userAgent = userAgent
        self.executor = executor
        self.decoderFactory = decoderFactory
        self.encoderFactory = encoderFactory
    }
}

public struct PlausibleHTTPExecutor: Sendable {
    public var execute: @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    public init(execute: @escaping @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)) {
        self.execute = execute
    }

    public static func urlSession(_ session: URLSession = .shared) -> Self {
        Self { request in
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PlausibleTransportError.invalidResponse
            }

            return (data, httpResponse)
        }
    }
}

extension JSONDecoder {
    public static func plausibleDefault() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            if let date = plausibleParseDate(string) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported Plausible date value: \(string)"
            )
        }
        return decoder
    }
}

extension JSONEncoder {
    public static func plausibleDefault() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private func plausibleParseDate(_ string: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    if let date = fractional.date(from: string) {
        return date
    }

    let basic = ISO8601DateFormatter()
    basic.formatOptions = [.withInternetDateTime]

    if let date = basic.date(from: string) {
        return date
    }

    let dateOnly = DateFormatter()
    dateOnly.calendar = Calendar(identifier: .iso8601)
    dateOnly.locale = Locale(identifier: "en_US_POSIX")
    dateOnly.timeZone = TimeZone(secondsFromGMT: 0)
    dateOnly.dateFormat = "yyyy-MM-dd"
    return dateOnly.date(from: string)
}
