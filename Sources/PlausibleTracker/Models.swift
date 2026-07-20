import Foundation

public enum EventPropertyValue: Encodable, Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        }
    }
}

extension EventPropertyValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension EventPropertyValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension EventPropertyValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension EventPropertyValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

public struct Revenue: Codable, Sendable, Equatable {
    public var currency: String
    public var amount: Decimal

    enum CodingKeys: String, CodingKey {
        case currency
        case amount
    }

    public init(currency: String, amount: Decimal) {
        self.currency = currency
        self.amount = amount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currency = try container.decode(String.self, forKey: .currency)

        if let string = try? container.decode(String.self, forKey: .amount),
           let value = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")) {
            amount = value
        } else {
            amount = try container.decode(Decimal.self, forKey: .amount)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currency, forKey: .currency)
        try container.encode(NSDecimalNumber(decimal: amount).stringValue, forKey: .amount)
    }
}

public struct EventRequest: Encodable, Sendable, Equatable {
    public var domain: String
    public var name: String
    public var url: String
    public var referrer: String?
    public var props: [String: EventPropertyValue]?
    public var revenue: Revenue?
    public var interactive: Bool?
    public var userAgent: String?
    public var forwardedFor: String?

    enum CodingKeys: String, CodingKey {
        case domain
        case name
        case url
        case referrer
        case props
        case revenue
        case interactive
    }

    public init(
        domain: String,
        name: String,
        url: String,
        referrer: String? = nil,
        props: [String: EventPropertyValue]? = nil,
        revenue: Revenue? = nil,
        interactive: Bool? = nil,
        userAgent: String? = nil,
        forwardedFor: String? = nil
    ) {
        self.domain = domain
        self.name = name
        self.url = url
        self.referrer = referrer
        self.props = props
        self.revenue = revenue
        self.interactive = interactive
        self.userAgent = userAgent
        self.forwardedFor = forwardedFor
    }

    public static func pageview(
        domain: String,
        url: String,
        referrer: String? = nil,
        props: [String: EventPropertyValue]? = nil,
        userAgent: String? = nil,
        forwardedFor: String? = nil
    ) -> Self {
        Self(
            domain: domain,
            name: "pageview",
            url: url,
            referrer: referrer,
            props: props,
            userAgent: userAgent,
            forwardedFor: forwardedFor
        )
    }

    public static func event(
        domain: String,
        name: String,
        url: String,
        referrer: String? = nil,
        props: [String: EventPropertyValue]? = nil,
        revenue: Revenue? = nil,
        interactive: Bool? = nil,
        userAgent: String? = nil,
        forwardedFor: String? = nil
    ) -> Self {
        Self(
            domain: domain,
            name: name,
            url: url,
            referrer: referrer,
            props: props,
            revenue: revenue,
            interactive: interactive,
            userAgent: userAgent,
            forwardedFor: forwardedFor
        )
    }
}

public struct EventResponse: Sendable, Equatable {
    public let statusCode: Int
    public let droppedCount: Int

    public var dropped: Bool { droppedCount > 0 }

    public init(statusCode: Int, droppedCount: Int) {
        self.statusCode = statusCode
        self.droppedCount = droppedCount
    }
}
