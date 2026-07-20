import Foundation
import PlausibleCore

public actor PlausibleTrackerClient {
    private let transport: any PlausibleTransport
    private let domain: String

    public init(configuration: PlausibleConfiguration = .init(), domain: String) {
        self.transport = DefaultPlausibleTransport(configuration: configuration)
        self.domain = domain
    }

    @discardableResult
    public func send(_ event: EventRequest) async throws -> EventResponse {
        var headers: [String: String] = [:]

        if let userAgent = event.userAgent {
            headers["User-Agent"] = userAgent
        }
        if let forwardedFor = event.forwardedFor {
            headers["X-Forwarded-For"] = forwardedFor
        }

        return try await transport.send(
            PlausibleRequest<EventResponse>(
                method: "POST",
                path: "/api/event",
                headers: headers,
                body: .json(event)
            ) { _, response, _ in
                EventResponse(
                    statusCode: response.statusCode,
                    droppedCount: Int(
                        response.value(forHTTPHeaderField: "x-plausible-dropped") ?? ""
                    ) ?? 0
                )
            }
        )
    }

    @discardableResult
    public func pageview(
        url: String,
        referrer: String? = nil,
        props: [String: EventPropertyValue]? = nil
    ) async throws -> EventResponse {
        try await send(.pageview(domain: domain, url: url, referrer: referrer, props: props))
    }

    @discardableResult
    public func event(
        name: String,
        url: String,
        referrer: String? = nil,
        props: [String: EventPropertyValue]? = nil,
        revenue: Revenue? = nil,
        interactive: Bool? = nil
    ) async throws -> EventResponse {
        try await send(
            .event(
                domain: domain,
                name: name,
                url: url,
                referrer: referrer,
                props: props,
                revenue: revenue,
                interactive: interactive
            )
        )
    }
}
