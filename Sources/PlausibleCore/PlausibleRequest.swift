import Foundation

public struct PlausibleRequest<Response: Sendable>: Sendable {
    public let method: String
    public let path: String
    public let auth: PlausibleAuth
    public let queryItems: [URLQueryItem]
    public let headers: [String: String]
    public let body: PlausibleRequestBody?
    let decode: @Sendable (Data, HTTPURLResponse, JSONDecoder) throws -> Response

    public init(
        method: String,
        path: String,
        auth: PlausibleAuth = .none,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: PlausibleRequestBody? = nil,
        decode: @escaping @Sendable (Data, HTTPURLResponse, JSONDecoder) throws -> Response
    ) {
        self.method = method
        self.path = path
        self.auth = auth
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.decode = decode
    }
}

public struct PlausibleRequestBody: Sendable {
    public let contentType: String
    let encode: @Sendable (JSONEncoder) throws -> Data

    public init(contentType: String, encode: @escaping @Sendable (JSONEncoder) throws -> Data) {
        self.contentType = contentType
        self.encode = encode
    }

    public static func json<Value: Encodable & Sendable>(_ value: Value) -> Self {
        Self(contentType: "application/json") { encoder in
            try encoder.encode(value)
        }
    }
}

public struct PlausibleRawResponse: Sendable, Equatable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data

    public init(statusCode: Int, headers: [String: String], body: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }

    public func decodeJSON(using decoder: JSONDecoder = .plausibleDefault()) throws -> JSONValue {
        try decoder.decode(JSONValue.self, from: body)
    }
}

extension PlausibleRequest where Response: Decodable {
    public static func json(
        method: String,
        path: String,
        auth: PlausibleAuth = .none,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: PlausibleRequestBody? = nil
    ) -> Self {
        Self(
            method: method,
            path: path,
            auth: auth,
            queryItems: queryItems,
            headers: headers,
            body: body
        ) { data, _, decoder in
            guard !data.isEmpty else {
                throw PlausibleTransportError.missingBody
            }

            do {
                return try decoder.decode(Response.self, from: data)
            } catch {
                throw PlausibleTransportError.decodingFailure(String(describing: error))
            }
        }
    }
}

extension PlausibleRequest where Response == PlausibleRawResponse {
    public static func raw(
        method: String,
        path: String,
        auth: PlausibleAuth = .none,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: PlausibleRequestBody? = nil
    ) -> Self {
        Self(
            method: method,
            path: path,
            auth: auth,
            queryItems: queryItems,
            headers: headers,
            body: body
        ) { data, response, _ in
            PlausibleRawResponse(
                statusCode: response.statusCode,
                headers: response.allHeaderFields.reduce(into: [:]) { result, entry in
                    result[String(describing: entry.key)] = String(describing: entry.value)
                },
                body: data
            )
        }
    }
}
