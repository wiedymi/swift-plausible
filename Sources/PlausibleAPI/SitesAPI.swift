import Foundation
import PlausibleCore

public struct SitesAPI: Sendable {
    let context: PlausibleAPIContext

    public func list(_ query: CursorQuery = .init()) async throws -> SiteList {
        try await context.transport.send(
            .json(
                method: "GET",
                path: "/api/v1/sites",
                auth: context.auth,
                queryItems: query.queryItems()
            )
        )
    }

    public func create(_ request: CreateSiteRequest) async throws -> Site {
        try await context.transport.send(
            .json(method: "POST", path: "/api/v1/sites", auth: context.auth, body: .json(request))
        )
    }

    public func get(siteID: String) async throws -> Site {
        try await context.transport.send(
            .json(method: "GET", path: "/api/v1/sites/\(pathSegment(siteID))", auth: context.auth)
        )
    }

    public func update(siteID: String, _ request: UpdateSiteRequest) async throws -> Site {
        try await context.transport.send(
            .json(
                method: "PUT",
                path: "/api/v1/sites/\(pathSegment(siteID))",
                auth: context.auth,
                body: .json(request)
            )
        )
    }

    public func delete(siteID: String) async throws -> DeletedResponse {
        try await context.transport.send(
            .json(method: "DELETE", path: "/api/v1/sites/\(pathSegment(siteID))", auth: context.auth)
        )
    }

    public func teams(_ query: CursorQuery = .init()) async throws -> TeamList {
        try await context.transport.send(
            .json(
                method: "GET",
                path: "/api/v1/sites/teams",
                auth: context.auth,
                queryItems: query.queryItems()
            )
        )
    }

    public func findOrCreateSharedLink(siteID: String, name: String) async throws -> SharedLink {
        try await context.transport.send(
            .json(
                method: "PUT",
                path: "/api/v1/sites/shared-links",
                auth: context.auth,
                body: .json(SharedLinkRequest(siteID: siteID, name: name))
            )
        )
    }

    public func goals(siteID: String, _ query: CursorQuery = .init()) async throws -> GoalList {
        var queryItems = query.queryItems()
        queryItems.append(URLQueryItem(name: "site_id", value: siteID))

        return try await context.transport.send(
            .json(
                method: "GET",
                path: "/api/v1/sites/goals",
                auth: context.auth,
                queryItems: queryItems
            )
        )
    }

    public func findOrCreateGoal(_ request: GoalRequest) async throws -> Goal {
        try await context.transport.send(
            .json(
                method: "PUT",
                path: "/api/v1/sites/goals",
                auth: context.auth,
                body: .json(request)
            )
        )
    }

    public func deleteGoal(goalID: Int, siteID: String) async throws -> DeletedResponse {
        try await context.transport.send(
            .json(
                method: "DELETE",
                path: "/api/v1/sites/goals/\(goalID)",
                auth: context.auth,
                body: .json(SiteIDRequest(siteID: siteID))
            )
        )
    }

    public func customProperties(siteID: String) async throws -> [CustomProperty] {
        let response: CustomPropertyList = try await context.transport.send(
            .json(
                method: "GET",
                path: "/api/v1/sites/custom-props",
                auth: context.auth,
                queryItems: [URLQueryItem(name: "site_id", value: siteID)]
            )
        )
        return response.properties
    }

    public func enableCustomProperty(siteID: String, property: String) async throws {
        try await context.transport.send(
            PlausibleRequest<Void>(
                method: "PUT",
                path: "/api/v1/sites/custom-props",
                auth: context.auth,
                body: .json(CustomPropertyRequest(siteID: siteID, property: property))
            ) { _, _, _ in () }
        )
    }

    public func disableCustomProperty(siteID: String, property: String) async throws {
        try await context.transport.send(
            PlausibleRequest<Void>(
                method: "DELETE",
                path: "/api/v1/sites/custom-props/\(pathSegment(property))",
                auth: context.auth,
                body: .json(SiteIDRequest(siteID: siteID))
            ) { _, _, _ in () }
        )
    }

    public func guests(siteID: String, _ query: CursorQuery = .init()) async throws -> GuestList {
        var queryItems = query.queryItems()
        queryItems.append(URLQueryItem(name: "site_id", value: siteID))

        return try await context.transport.send(
            .json(
                method: "GET",
                path: "/api/v1/sites/guests",
                auth: context.auth,
                queryItems: queryItems
            )
        )
    }

    public func findOrCreateGuest(siteID: String, email: String, role: GuestRole) async throws -> Guest {
        try await context.transport.send(
            .json(
                method: "PUT",
                path: "/api/v1/sites/guests",
                auth: context.auth,
                body: .json(GuestRequest(siteID: siteID, email: email, role: role))
            )
        )
    }

    public func removeGuest(siteID: String, email: String) async throws -> DeletedResponse {
        try await context.transport.send(
            .json(
                method: "DELETE",
                path: "/api/v1/sites/guests/\(pathSegment(email))",
                auth: context.auth,
                queryItems: [URLQueryItem(name: "site_id", value: siteID)]
            )
        )
    }
}

private struct SiteIDRequest: Encodable, Sendable {
    let siteID: String

    enum CodingKeys: String, CodingKey {
        case siteID = "site_id"
    }
}

private struct SharedLinkRequest: Encodable, Sendable {
    let siteID: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case siteID = "site_id"
        case name
    }
}

private struct CustomPropertyRequest: Encodable, Sendable {
    let siteID: String
    let property: String

    enum CodingKeys: String, CodingKey {
        case siteID = "site_id"
        case property
    }
}

private struct GuestRequest: Encodable, Sendable {
    let siteID: String
    let email: String
    let role: GuestRole

    enum CodingKeys: String, CodingKey {
        case siteID = "site_id"
        case email
        case role
    }
}

private struct CustomPropertyList: Decodable, Sendable {
    let properties: [CustomProperty]

    enum CodingKeys: String, CodingKey {
        case customProperties = "custom_properties"
        case customProps = "custom_props"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        properties = try container.decodeIfPresent([CustomProperty].self, forKey: .customProperties)
            ?? container.decode([CustomProperty].self, forKey: .customProps)
    }
}

private func pathSegment(_ value: String) -> String {
    var allowed = CharacterSet.urlPathAllowed
    allowed.remove(charactersIn: "/?#")
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
}
