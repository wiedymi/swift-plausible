import Foundation
import PlausibleCore

public struct Site: Decodable, Sendable, Equatable {
    public let domain: String
    public let timezone: String
    public let customProperties: [String]?
    public let trackerScriptConfiguration: JSONValue?

    enum CodingKeys: String, CodingKey {
        case domain
        case timezone
        case customProperties = "custom_properties"
        case trackerScriptConfiguration = "tracker_script_configuration"
    }

    public init(
        domain: String,
        timezone: String,
        customProperties: [String]? = nil,
        trackerScriptConfiguration: JSONValue? = nil
    ) {
        self.domain = domain
        self.timezone = timezone
        self.customProperties = customProperties
        self.trackerScriptConfiguration = trackerScriptConfiguration
    }
}

public struct CreateSiteRequest: Encodable, Sendable, Equatable {
    public var domain: String
    public var timezone: String?
    public var teamID: String?

    enum CodingKeys: String, CodingKey {
        case domain
        case timezone
        case teamID = "team_id"
    }

    public init(domain: String, timezone: String? = nil, teamID: String? = nil) {
        self.domain = domain
        self.timezone = timezone
        self.teamID = teamID
    }
}

public struct UpdateSiteRequest: Encodable, Sendable, Equatable {
    public var domain: String?

    enum CodingKeys: String, CodingKey {
        case domain
    }

    public init(domain: String? = nil) {
        self.domain = domain
    }
}

public struct CursorQuery: Sendable, Equatable {
    public var after: String?
    public var before: String?
    public var limit: Int?
    public var teamID: String?

    public init(after: String? = nil, before: String? = nil, limit: Int? = nil, teamID: String? = nil) {
        self.after = after
        self.before = before
        self.limit = limit
        self.teamID = teamID
    }

    func queryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []

        if let after {
            items.append(URLQueryItem(name: "after", value: after))
        }
        if let before {
            items.append(URLQueryItem(name: "before", value: before))
        }
        if let limit {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let teamID {
            items.append(URLQueryItem(name: "team_id", value: teamID))
        }

        return items
    }
}

public struct SharedLink: Decodable, Sendable, Equatable {
    public let name: String
    public let url: String

    enum CodingKeys: String, CodingKey {
        case name
        case url
    }

    public init(name: String, url: String) {
        self.name = name
        self.url = url
    }
}

public struct GoalType: RawRepresentable, ExpressibleByStringLiteral, Hashable, Sendable, Codable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public static let event = Self(rawValue: "event")
    public static let page = Self(rawValue: "page")
}

public struct Goal: Decodable, Sendable, Equatable {
    public let id: Int
    public let goalType: GoalType
    public let displayName: String?
    public let eventName: String?
    public let pagePath: String?
    public let customProps: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id
        case goalType = "goal_type"
        case displayName = "display_name"
        case eventName = "event_name"
        case pagePath = "page_path"
        case customProps = "custom_props"
    }

    public init(
        id: Int,
        goalType: GoalType,
        displayName: String? = nil,
        eventName: String? = nil,
        pagePath: String? = nil,
        customProps: [String: String]? = nil
    ) {
        self.id = id
        self.goalType = goalType
        self.displayName = displayName
        self.eventName = eventName
        self.pagePath = pagePath
        self.customProps = customProps
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let value = try? container.decode(Int.self, forKey: .id) {
            id = value
        } else {
            let string = try container.decode(String.self, forKey: .id)
            guard let value = Int(string) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .id,
                    in: container,
                    debugDescription: "Goal id is not an integer"
                )
            }
            id = value
        }

        goalType = try container.decode(GoalType.self, forKey: .goalType)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        eventName = try container.decodeIfPresent(String.self, forKey: .eventName)
        pagePath = try container.decodeIfPresent(String.self, forKey: .pagePath)
        customProps = try container.decodeIfPresent([String: String].self, forKey: .customProps)
    }
}

public struct GoalRequest: Encodable, Sendable, Equatable {
    public var siteID: String
    public var goalType: GoalType
    public var eventName: String?
    public var pagePath: String?
    public var displayName: String?
    public var customProps: [String: String]?

    enum CodingKeys: String, CodingKey {
        case siteID = "site_id"
        case goalType = "goal_type"
        case eventName = "event_name"
        case pagePath = "page_path"
        case displayName = "display_name"
        case customProps = "custom_props"
    }

    public init(
        siteID: String,
        goalType: GoalType,
        eventName: String? = nil,
        pagePath: String? = nil,
        displayName: String? = nil,
        customProps: [String: String]? = nil
    ) {
        self.siteID = siteID
        self.goalType = goalType
        self.eventName = eventName
        self.pagePath = pagePath
        self.displayName = displayName
        self.customProps = customProps
    }
}

public struct GuestRole: RawRepresentable, ExpressibleByStringLiteral, Hashable, Sendable, Codable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public static let viewer = Self(rawValue: "viewer")
    public static let editor = Self(rawValue: "editor")
}

public struct Guest: Decodable, Sendable, Equatable {
    public let email: String
    public let role: GuestRole
    public let status: String

    enum CodingKeys: String, CodingKey {
        case email
        case role
        case status
    }

    public init(email: String, role: GuestRole, status: String) {
        self.email = email
        self.role = role
        self.status = status
    }
}

public struct DeletedResponse: Decodable, Sendable, Equatable {
    public let deleted: Bool

    enum CodingKeys: String, CodingKey {
        case deleted
    }

    public init(deleted: Bool) {
        self.deleted = deleted
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let value = try? container.decode(Bool.self, forKey: .deleted) {
            deleted = value
            return
        }

        let string = try container.decode(String.self, forKey: .deleted)
        guard let value = Bool(string) else {
            throw DecodingError.dataCorruptedError(
                forKey: .deleted,
                in: container,
                debugDescription: "Deleted value is neither a boolean nor a boolean string"
            )
        }
        deleted = value
    }
}

public struct Team: Decodable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let apiAvailable: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case apiAvailable = "api_available"
    }

    public init(id: String, name: String, apiAvailable: Bool) {
        self.id = id
        self.name = name
        self.apiAvailable = apiAvailable
    }
}

public struct CustomProperty: Decodable, Sendable, Equatable {
    public let property: String

    enum CodingKeys: String, CodingKey {
        case property
    }

    public init(property: String) {
        self.property = property
    }
}

public struct PaginationMeta: Decodable, Sendable, Equatable {
    public let after: String?
    public let before: String?
    public let limit: Int

    enum CodingKeys: String, CodingKey {
        case after
        case before
        case limit
    }

    public init(after: String? = nil, before: String? = nil, limit: Int) {
        self.after = after
        self.before = before
        self.limit = limit
    }
}

public struct SiteList: Decodable, Sendable, Equatable {
    public let sites: [Site]
    public let meta: PaginationMeta

    enum CodingKeys: String, CodingKey {
        case sites
        case meta
    }

    public init(sites: [Site], meta: PaginationMeta) {
        self.sites = sites
        self.meta = meta
    }
}

public struct TeamList: Decodable, Sendable, Equatable {
    public let teams: [Team]
    public let meta: PaginationMeta

    enum CodingKeys: String, CodingKey {
        case teams
        case meta
    }

    public init(teams: [Team], meta: PaginationMeta) {
        self.teams = teams
        self.meta = meta
    }
}

public struct GoalList: Decodable, Sendable, Equatable {
    public let goals: [Goal]
    public let meta: PaginationMeta

    enum CodingKeys: String, CodingKey {
        case goals
        case meta
    }

    public init(goals: [Goal], meta: PaginationMeta) {
        self.goals = goals
        self.meta = meta
    }
}

public struct GuestList: Decodable, Sendable, Equatable {
    public let guests: [Guest]
    public let meta: PaginationMeta

    enum CodingKeys: String, CodingKey {
        case guests
        case meta
    }

    public init(guests: [Guest], meta: PaginationMeta) {
        self.guests = guests
        self.meta = meta
    }
}
