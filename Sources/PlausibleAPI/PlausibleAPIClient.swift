import Foundation
import PlausibleCore

public struct PlausibleAPIClient: Sendable {
    let context: PlausibleAPIContext

    public init(
        configuration: PlausibleConfiguration = .init(),
        auth: PlausibleAuth = .none,
        transport: (any PlausibleTransport)? = nil
    ) {
        let resolvedTransport = transport ?? DefaultPlausibleTransport(configuration: configuration)
        self.context = PlausibleAPIContext(transport: resolvedTransport, auth: auth)
    }

    init(context: PlausibleAPIContext) {
        self.context = context
    }

    public func withAuth(_ auth: PlausibleAuth) -> Self {
        Self(context: context.withAuth(auth))
    }

    public var stats: StatsAPI { StatsAPI(context: context) }
    public var sites: SitesAPI { SitesAPI(context: context) }
    public var raw: RawAPI { RawAPI(context: context) }
}

public struct RawAPI: Sendable {
    let context: PlausibleAPIContext

    public func get(
        path: String,
        queryItems: [URLQueryItem] = [],
        auth: PlausibleAuth? = nil
    ) async throws -> PlausibleRawResponse {
        try await context.transport.send(
            .raw(method: "GET", path: path, auth: auth ?? context.auth, queryItems: queryItems)
        )
    }

    public func post<Body: Encodable & Sendable>(
        path: String,
        body: Body,
        auth: PlausibleAuth? = nil
    ) async throws -> PlausibleRawResponse {
        try await context.transport.send(
            .raw(method: "POST", path: path, auth: auth ?? context.auth, body: .json(body))
        )
    }

    public func put<Body: Encodable & Sendable>(
        path: String,
        body: Body,
        auth: PlausibleAuth? = nil
    ) async throws -> PlausibleRawResponse {
        try await context.transport.send(
            .raw(method: "PUT", path: path, auth: auth ?? context.auth, body: .json(body))
        )
    }

    public func delete(
        path: String,
        auth: PlausibleAuth? = nil
    ) async throws -> PlausibleRawResponse {
        try await context.transport.send(
            .raw(method: "DELETE", path: path, auth: auth ?? context.auth)
        )
    }

    public func delete<Body: Encodable & Sendable>(
        path: String,
        body: Body,
        auth: PlausibleAuth? = nil
    ) async throws -> PlausibleRawResponse {
        try await context.transport.send(
            .raw(
                method: "DELETE",
                path: path,
                auth: auth ?? context.auth,
                body: .json(body)
            )
        )
    }
}
