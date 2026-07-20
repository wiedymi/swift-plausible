import Foundation
import PlausibleCore

public struct Metric: RawRepresentable, ExpressibleByStringLiteral, Hashable, Sendable, Codable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public static let visitors = Self(rawValue: "visitors")
    public static let visits = Self(rawValue: "visits")
    public static let pageviews = Self(rawValue: "pageviews")
    public static let viewsPerVisit = Self(rawValue: "views_per_visit")
    public static let bounceRate = Self(rawValue: "bounce_rate")
    public static let visitDuration = Self(rawValue: "visit_duration")
    public static let events = Self(rawValue: "events")
    public static let scrollDepth = Self(rawValue: "scroll_depth")
    public static let percentage = Self(rawValue: "percentage")
    public static let conversionRate = Self(rawValue: "conversion_rate")
    public static let groupConversionRate = Self(rawValue: "group_conversion_rate")
    public static let averageRevenue = Self(rawValue: "average_revenue")
    public static let totalRevenue = Self(rawValue: "total_revenue")
    public static let timeOnPage = Self(rawValue: "time_on_page")
}

public struct Dimension: RawRepresentable, ExpressibleByStringLiteral, Hashable, Sendable, Codable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public static let eventGoal = Self(rawValue: "event:goal")
    public static let eventPage = Self(rawValue: "event:page")
    public static let eventHostname = Self(rawValue: "event:hostname")
    public static let entryPage = Self(rawValue: "visit:entry_page")
    public static let entryPageHostname = Self(rawValue: "visit:entry_page_hostname")
    public static let exitPage = Self(rawValue: "visit:exit_page")
    public static let exitPageHostname = Self(rawValue: "visit:exit_page_hostname")
    public static let source = Self(rawValue: "visit:source")
    public static let referrer = Self(rawValue: "visit:referrer")
    public static let channel = Self(rawValue: "visit:channel")
    public static let utmMedium = Self(rawValue: "visit:utm_medium")
    public static let utmSource = Self(rawValue: "visit:utm_source")
    public static let utmCampaign = Self(rawValue: "visit:utm_campaign")
    public static let utmContent = Self(rawValue: "visit:utm_content")
    public static let utmTerm = Self(rawValue: "visit:utm_term")
    public static let device = Self(rawValue: "visit:device")
    public static let browser = Self(rawValue: "visit:browser")
    public static let browserVersion = Self(rawValue: "visit:browser_version")
    public static let os = Self(rawValue: "visit:os")
    public static let osVersion = Self(rawValue: "visit:os_version")
    public static let country = Self(rawValue: "visit:country")
    public static let region = Self(rawValue: "visit:region")
    public static let city = Self(rawValue: "visit:city")
    public static let countryName = Self(rawValue: "visit:country_name")
    public static let regionName = Self(rawValue: "visit:region_name")
    public static let cityName = Self(rawValue: "visit:city_name")
    public static let time = Self(rawValue: "time")
    public static let timeHour = Self(rawValue: "time:hour")
    public static let timeDay = Self(rawValue: "time:day")
    public static let timeWeek = Self(rawValue: "time:week")
    public static let timeMonth = Self(rawValue: "time:month")

    public static func eventProperty(_ name: String) -> Self {
        Self(rawValue: "event:props:\(name)")
    }

    public static func utm(_ name: String) -> Self {
        Self(rawValue: "visit:utm_\(name)")
    }
}

public enum DateRange: Encodable, Sendable, Equatable {
    case shortcut(String)
    case dates(from: String, to: String)

    public static let last7Days = Self.shortcut("7d")
    public static let last28Days = Self.shortcut("28d")
    public static let last30Days = Self.shortcut("30d")
    public static let last91Days = Self.shortcut("91d")
    public static let day = Self.shortcut("day")
    public static let last24Hours = Self.shortcut("24h")
    public static let month = Self.shortcut("month")
    public static let last6Months = Self.shortcut("6mo")
    public static let last12Months = Self.shortcut("12mo")
    public static let year = Self.shortcut("year")
    public static let all = Self.shortcut("all")

    public static func dates(from: Date, to: Date, includeTime: Bool) -> Self {
        .dates(
            from: plausibleDateRangeString(from, includeTime: includeTime),
            to: plausibleDateRangeString(to, includeTime: includeTime)
        )
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .shortcut(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .dates(let from, let to):
            var container = encoder.unkeyedContainer()
            try container.encode(from)
            try container.encode(to)
        }
    }
}

private func plausibleDateRangeString(_ date: Date, includeTime: Bool) -> String {
    if includeTime {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

public indirect enum StatsFilter: Encodable, Sendable, Equatable {
    public struct Options: Sendable, Equatable {
        public var caseSensitive: Bool

        public init(caseSensitive: Bool) {
            self.caseSensitive = caseSensitive
        }

        public static let caseInsensitive = Self(caseSensitive: false)
    }

    case `is`(Dimension, [String], options: Options? = nil)
    case isNot(Dimension, [String], options: Options? = nil)
    case contains(Dimension, [String], options: Options? = nil)
    case containsNot(Dimension, [String], options: Options? = nil)
    case matches(Dimension, [String], options: Options? = nil)
    case matchesNot(Dimension, [String], options: Options? = nil)
    case and([StatsFilter])
    case or([StatsFilter])
    case not(StatsFilter)
    case hasDone(StatsFilter)
    case hasNotDone(StatsFilter)
    case segment(Int)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case .is(let dimension, let clauses, let options):
            try encodeSimple("is", dimension, clauses, options, into: &container)
        case .isNot(let dimension, let clauses, let options):
            try encodeSimple("is_not", dimension, clauses, options, into: &container)
        case .contains(let dimension, let clauses, let options):
            try encodeSimple("contains", dimension, clauses, options, into: &container)
        case .containsNot(let dimension, let clauses, let options):
            try encodeSimple("contains_not", dimension, clauses, options, into: &container)
        case .matches(let dimension, let clauses, let options):
            try encodeSimple("matches", dimension, clauses, options, into: &container)
        case .matchesNot(let dimension, let clauses, let options):
            try encodeSimple("matches_not", dimension, clauses, options, into: &container)
        case .and(let filters):
            try container.encode("and")
            try container.encode(filters)
        case .or(let filters):
            try container.encode("or")
            try container.encode(filters)
        case .not(let filter):
            try container.encode("not")
            try container.encode(filter)
        case .hasDone(let filter):
            try container.encode("has_done")
            try container.encode(filter)
        case .hasNotDone(let filter):
            try container.encode("has_not_done")
            try container.encode(filter)
        case .segment(let id):
            try container.encode("is")
            try container.encode("segment")
            try container.encode([id])
        }
    }

    private func encodeSimple(
        _ operation: String,
        _ dimension: Dimension,
        _ clauses: [String],
        _ options: Options?,
        into container: inout UnkeyedEncodingContainer
    ) throws {
        try container.encode(operation)
        try container.encode(dimension)
        try container.encode(clauses)

        if let options {
            try container.encode(["case_sensitive": options.caseSensitive])
        }
    }
}

public enum SortDirection: String, Codable, Sendable, Equatable {
    case asc
    case desc
}

public struct OrderBy: Encodable, Sendable, Equatable {
    public var target: String
    public var direction: SortDirection

    public init(target: String, direction: SortDirection) {
        self.target = target
        self.direction = direction
    }

    public init(_ metric: Metric, direction: SortDirection) {
        self.init(target: metric.rawValue, direction: direction)
    }

    public init(_ dimension: Dimension, direction: SortDirection) {
        self.init(target: dimension.rawValue, direction: direction)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(target)
        try container.encode(direction)
    }
}

public struct Include: Encodable, Sendable, Equatable {
    public var imports: Bool?
    public var timeLabels: Bool?
    public var totalRows: Bool?

    enum CodingKeys: String, CodingKey {
        case imports
        case timeLabels = "time_labels"
        case totalRows = "total_rows"
    }

    public init(imports: Bool? = nil, timeLabels: Bool? = nil, totalRows: Bool? = nil) {
        self.imports = imports
        self.timeLabels = timeLabels
        self.totalRows = totalRows
    }
}

public struct Pagination: Encodable, Sendable, Equatable {
    public var limit: Int?
    public var offset: Int?

    public init(limit: Int? = nil, offset: Int? = nil) {
        self.limit = limit
        self.offset = offset
    }
}

public struct StatsQuery: Encodable, Sendable {
    public var siteID: String
    public var metrics: [Metric]
    public var dateRange: DateRange
    public var dimensions: [Dimension]
    public var filters: [StatsFilter]
    public var orderBy: [OrderBy]?
    public var include: Include?
    public var pagination: Pagination?

    enum CodingKeys: String, CodingKey {
        case siteID = "site_id"
        case metrics
        case dateRange = "date_range"
        case dimensions
        case filters
        case orderBy = "order_by"
        case include
        case pagination
    }

    public init(
        siteID: String,
        metrics: [Metric],
        dateRange: DateRange,
        dimensions: [Dimension] = [],
        filters: [StatsFilter] = [],
        orderBy: [OrderBy]? = nil,
        include: Include? = nil,
        pagination: Pagination? = nil
    ) {
        self.siteID = siteID
        self.metrics = metrics
        self.dateRange = dateRange
        self.dimensions = dimensions
        self.filters = filters
        self.orderBy = orderBy
        self.include = include
        self.pagination = pagination
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(siteID, forKey: .siteID)
        try container.encode(metrics, forKey: .metrics)
        try container.encode(dateRange, forKey: .dateRange)

        if !dimensions.isEmpty {
            try container.encode(dimensions, forKey: .dimensions)
        }

        if !filters.isEmpty {
            try container.encode(filters, forKey: .filters)
        }

        try container.encodeIfPresent(orderBy, forKey: .orderBy)
        try container.encodeIfPresent(include, forKey: .include)
        try container.encodeIfPresent(pagination, forKey: .pagination)
    }
}

public enum MetricValue: Decodable, Sendable, Equatable {
    case number(Double)
    case null

    public var doubleValue: Double? {
        guard case .number(let value) = self else { return nil }
        return value
    }

    public var intValue: Int? {
        guard case .number(let value) = self else { return nil }
        return Int(exactly: value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else {
            self = .number(try container.decode(Double.self))
        }
    }
}

public struct MetricWarning: Decodable, Sendable, Equatable {
    public let code: String
    public let warning: String

    public init(code: String, warning: String) {
        self.code = code
        self.warning = warning
    }
}

public struct StatsResponse: Decodable, Sendable {
    public let results: [Row]
    public let meta: Meta
    public let query: JSONValue?

    public init(results: [Row], meta: Meta, query: JSONValue? = nil) {
        self.results = results
        self.meta = meta
        self.query = query
    }

    public struct Row: Decodable, Sendable, Equatable {
        public let metrics: [MetricValue]
        public let dimensions: [String]

        public init(metrics: [MetricValue], dimensions: [String]) {
            self.metrics = metrics
            self.dimensions = dimensions
        }
    }

    public struct Meta: Decodable, Sendable, Equatable {
        public let importsIncluded: Bool?
        public let importsSkipReason: String?
        public let importsWarning: String?
        public let timeLabels: [String]?
        public let totalRows: Int?
        public let metricWarnings: [String: MetricWarning]?

        enum CodingKeys: String, CodingKey {
            case importsIncluded = "imports_included"
            case importsSkipReason = "imports_skip_reason"
            case importsWarning = "imports_warning"
            case timeLabels = "time_labels"
            case totalRows = "total_rows"
            case metricWarnings = "metric_warnings"
        }

        public init(
            importsIncluded: Bool? = nil,
            importsSkipReason: String? = nil,
            importsWarning: String? = nil,
            timeLabels: [String]? = nil,
            totalRows: Int? = nil,
            metricWarnings: [String: MetricWarning]? = nil
        ) {
            self.importsIncluded = importsIncluded
            self.importsSkipReason = importsSkipReason
            self.importsWarning = importsWarning
            self.timeLabels = timeLabels
            self.totalRows = totalRows
            self.metricWarnings = metricWarnings
        }
    }

}
