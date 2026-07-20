import Foundation

public protocol PlausibleTransport: Sendable {
    func send<Response: Sendable>(_ request: PlausibleRequest<Response>) async throws -> Response
}

public struct DefaultPlausibleTransport: PlausibleTransport, Sendable {
    public let configuration: PlausibleConfiguration

    public init(configuration: PlausibleConfiguration) {
        self.configuration = configuration
    }

    public func send<Response: Sendable>(_ request: PlausibleRequest<Response>) async throws -> Response {
        let urlRequest = try makeURLRequest(from: request)
        let (data, response) = try await configuration.executor.execute(urlRequest)

        if !(200..<300).contains(response.statusCode) {
            let decoder = configuration.decoderFactory()

            if let apiError = try? decoder.decode(PlausibleAPIError.self, from: data) {
                throw PlausibleTransportError.api(apiError, statusCode: response.statusCode)
            }

            throw PlausibleTransportError.unexpectedStatus(response.statusCode)
        }

        return try request.decode(data, response, configuration.decoderFactory())
    }

    private func makeURLRequest<Response>(from request: PlausibleRequest<Response>) throws -> URLRequest {
        guard let url = URL(string: request.path, relativeTo: configuration.baseURL) else {
            throw PlausibleTransportError.invalidURL(request.path)
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw PlausibleTransportError.invalidURL(request.path)
        }

        if !request.queryItems.isEmpty {
            components.queryItems = request.queryItems
        }

        guard let finalURL = components.url else {
            throw PlausibleTransportError.invalidURL(request.path)
        }

        var urlRequest = URLRequest(url: finalURL)
        urlRequest.httpMethod = request.method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let userAgent = configuration.userAgent {
            urlRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }

        request.auth.apply(to: &urlRequest)

        for (header, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: header)
        }

        if let body = request.body {
            do {
                urlRequest.httpBody = try body.encode(configuration.encoderFactory())
            } catch {
                throw PlausibleTransportError.encodingFailure(String(describing: error))
            }
            urlRequest.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
        }

        return urlRequest
    }
}
