# Plausible Specification

## Status

Draft 0.1

## Reference Source

This SDK is specified against the public Plausible API documentation:

- Events API: `https://plausible.io/docs/events-api`
- Stats API v2: `https://plausible.io/docs/stats-api`
- Sites API: `https://plausible.io/docs/sites-api`

The upstream Plausible source is checked in as a git submodule at
`refs/plausible` for verifying behavior the docs leave ambiguous (exact
response shapes, error envelopes, header handling):

- Upstream repository: `https://github.com/plausible/analytics`
- Submodule path: `refs/plausible`
- Observed upstream branch: `master`
- Observed upstream commit: `53c831a8416d3db221416cd5504b74edc609356b`
- Observed upstream commit date: `2026-07-16`

Key upstream entry points:

- Events ingestion: `lib/plausible_web/controllers/api/external_controller.ex`
- Stats API v2: `lib/plausible_web/controllers/api/external_query_api_controller.ex`
  and `lib/plausible/stats/api_query_parser.ex`
- Sites API (Enterprise Edition tree):
  `extra/lib/plausible_web/controllers/api/external_sites_controller.ex`

The documented contracts are canonical; the source resolves ambiguity.

## Problem

We want a Swift SDK for Plausible that can:

- query the Stats API v2 for dashboard-style analytics reads
- manage sites, goals, shared links, custom properties, and guests via the Sites API
- send pageview and custom events from Apple apps via the Events API

## Goals

- Ship as a Swift Package Manager package.
- Use native Swift concurrency (`async`/`await`) as the primary API.
- Typed access to the three documented API surfaces.
- Keep a raw request escape hatch for undocumented or future endpoints.
- Separate management/read API concerns from tracking concerns.
- Mirror the architecture of `swift-umami` so the two SDKs feel like siblings.

## Non-Goals

- Reproduce the JavaScript tracker feature-for-feature (no automatic engagement
  events, scroll depth, outbound link tracking, or hash routing).
- Support the legacy Stats API v1 (`/api/v1/stats/...`).
- Browser cookie/session emulation. Plausible is cookieless; visitor identity is
  derived server-side from User-Agent + IP.
- Linux support in the first release.

## Upstream API Observations

- Stats API v2 is a single endpoint: `POST /api/v2/query` with a JSON query
  document. Auth is `Authorization: Bearer <api-key>`. Default rate limit is
  600 requests/hour.
- Sites API lives under `/api/v1/sites...`, same bearer auth, but requires a
  Sites API key (Enterprise / self-hosted feature). List endpoints use cursor
  pagination (`after`, `before`, `limit`).
- Events API is `POST /api/event`, unauthenticated. Responds `202` with `{}`
  even when the event is dropped; dropped events are signaled via the
  `x-plausible-dropped` response header, whose value is the **count** of
  dropped events (verified in upstream `external_controller.ex`, which emits
  `Enum.count(dropped)`). `X-Debug-Request: true` returns `200` with the IP
  used for visitor counting.
- The `User-Agent` header and client IP (optionally overridden with
  `X-Forwarded-For`) determine unique-visitor identity for events.
- Error payloads are JSON shaped as `{"error": "message"}` for Stats and Sites
  endpoints (verified in upstream `PlausibleWeb.Api.Helpers`). The Events API
  additionally returns `{"errors": {"field": ["message", ...]}}` for `400`
  validation failures (Ecto changeset traversal in `external_controller.ex`).
- Stats v2 query documents mix heterogeneous JSON: `date_range` is a string
  shortcut or a 2-element array; filters are nested arrays like
  `["is", "visit:country", ["DE"]]` and logical trees `["and", [...]]`.

## Product Shape

Two primary SDK surfaces, sharing a transport core, mirroring swift-umami:

1. `PlausibleAPIClient` — typed client for Stats API v2 and Sites API.
2. `PlausibleTrackerClient` — actor for Events API ingestion.

Shared core:

- `PlausibleCore`
  - HTTP transport (`PlausibleTransport` protocol + `DefaultPlausibleTransport`)
  - configuration (`PlausibleConfiguration`, `PlausibleHTTPExecutor`)
  - auth (`PlausibleAuth`)
  - request building (`PlausibleRequest<Response>`, `PlausibleRequestBody`,
    `PlausibleRawResponse`)
  - error mapping (`PlausibleTransportError`, `PlausibleAPIError`)
  - `JSONValue` (same shape as UmamiCore's)

## Package Layout

```text
Package.swift
Sources/
  PlausibleCore/
    PlausibleConfiguration.swift
    PlausibleAuth.swift
    PlausibleRequest.swift
    PlausibleTransport.swift
    PlausibleErrors.swift
    JSONValue.swift
  PlausibleAPI/
    PlausibleAPIClient.swift
    APIContext.swift
    StatsAPI.swift
    StatsModels.swift
    SitesAPI.swift
    SitesModels.swift
  PlausibleTracker/
    PlausibleTrackerClient.swift
    Models.swift
  Plausible/
    Exports.swift        // @_exported import of the three modules
Tests/
  PlausibleTests/
    PlausibleTests.swift
```

Products: `Plausible` (umbrella), `PlausibleCore`, `PlausibleAPI`,
`PlausibleTracker` — one target each, same dependency graph as swift-umami.

## Supported Platforms

- Swift tools 6.0, Swift 6 language mode
- iOS 15+, macOS 12+, tvOS 15+, watchOS 8+, visionOS 1+

## Configuration

```swift
public struct PlausibleConfiguration: Sendable {
    public var baseURL: URL            // default https://plausible.io
    public var userAgent: String?
    public var executor: PlausibleHTTPExecutor
    public var decoderFactory: @Sendable () -> JSONDecoder
    public var encoderFactory: @Sendable () -> JSONEncoder

    public init(
        baseURL: URL = URL(string: "https://plausible.io")!,
        userAgent: String? = nil,
        executor: PlausibleHTTPExecutor = .urlSession(.shared),
        decoderFactory: ... = { JSONDecoder.plausibleDefault() },
        encoderFactory: ... = { JSONEncoder.plausibleDefault() }
    )
}
```

`PlausibleHTTPExecutor` is identical in shape to `UmamiHTTPExecutor`: a
`@Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)` closure with a
`.urlSession(_:)` factory. This is the test seam.

`JSONDecoder.plausibleDefault()`: ISO-8601 dates with and without fractional
seconds, plus plain `yyyy-MM-dd` (Stats time labels/custom ranges use ISO
dates). `JSONEncoder.plausibleDefault()`: `.iso8601` dates. No global
snake_case conversion — models declare explicit `CodingKeys`.

There is no `apiPath` remapping (Umami-cloud-specific); paths are literal.

## Authentication Model

```swift
public enum PlausibleAuth: Sendable, Equatable {
    case none
    case apiKey(String)   // Authorization: Bearer <key>

    func apply(to request: inout URLRequest)
}
```

Stats and Sites use `.apiKey` (they are distinct key types server-side but the
same header mechanics). The Events API is `.none`.

## Error Model

```swift
public struct PlausibleAPIError: Decodable, Error, Sendable, Equatable {
    public let message: String
    public let fieldErrors: [String: [String]]?
    // decoded from {"error": "..."} or {"errors": {"field": ["msg"]}};
    // for the latter, message is a joined human-readable summary
}

public enum PlausibleTransportError: Error, Sendable {
    case invalidURL(String)
    case invalidResponse
    case encodingFailure(String)
    case decodingFailure(String)
    case missingBody
    case unexpectedStatus(Int)
    case api(PlausibleAPIError, statusCode: Int)
}
```

Transport pipeline: non-2xx → try to decode `{"error": String}` → throw
`.api(...)`, else `.unexpectedStatus`. Mirrors `DefaultUmamiTransport`.

## Public API Surface

### `PlausibleAPIClient`

```swift
public struct PlausibleAPIClient: Sendable {
    public init(
        configuration: PlausibleConfiguration = .init(),
        auth: PlausibleAuth = .none,
        transport: (any PlausibleTransport)? = nil
    )

    public func withAuth(_ auth: PlausibleAuth) -> Self

    public var stats: StatsAPI { get }
    public var sites: SitesAPI { get }
    public var raw: RawAPI { get }
}
```

`RawAPI`: `get(path:queryItems:auth:)`, `post(path:body:auth:)`,
`put(path:body:auth:)`, `delete(path:body:auth:)` returning
`PlausibleRawResponse` — same shape as swift-umami's plus PUT, and DELETE takes
an optional body (Sites API DELETE endpoints require JSON bodies).

### Stats API v2

```swift
public struct StatsAPI: Sendable {
    public func query(_ query: StatsQuery) async throws -> StatsResponse
}
```

`POST /api/v2/query`. Query document models:

```swift
public struct StatsQuery: Encodable, Sendable {
    public var siteID: String                 // "site_id"
    public var metrics: [Metric]
    public var dateRange: DateRange           // "date_range"
    public var dimensions: [Dimension]        // omit when empty
    public var filters: [StatsFilter]         // omit when empty
    public var orderBy: [OrderBy]?            // "order_by", [[target, dir]]
    public var include: Include?
    public var pagination: Pagination?
}
```

- `Metric`: `RawRepresentable` struct over `String` (also
  `ExpressibleByStringLiteral`, `Hashable`, `Sendable`, `Codable`) with static
  constants: `visitors`, `visits`, `pageviews`, `viewsPerVisit`
  (`views_per_visit`), `bounceRate`, `visitDuration`, `events`, `scrollDepth`,
  `percentage`, `conversionRate`, `groupConversionRate`, `averageRevenue`,
  `totalRevenue`, `timeOnPage`. Raw-representable (not enum) so new upstream
  metrics never break the SDK.
- `Dimension`: same pattern. Statics for `event:goal`, `event:page`,
  `event:hostname`, all documented `visit:*` dimensions, and time dimensions
  `time`, `time:hour`, `time:day`, `time:week`, `time:month`. Plus factories:
  `.eventProperty("logged_in")` → `event:props:logged_in`,
  `.utm("source")`-style statics for `visit:utm_medium|source|campaign|content|term`.
- `DateRange`: enum with custom `Encodable` —
  `.shortcut(String)` encoding as a bare string, with statics `.last7Days`
  ("7d"), `.last28Days`, `.last30Days`, `.last91Days`, `.day`, `.last24Hours`
  ("24h"), `.month`, `.last6Months` ("6mo"), `.last12Months` ("12mo"), `.year`,
  `.all`; `.dates(from: String, to: String)` encoding as a 2-element array
  (accepts full ISO-8601 timestamps too); convenience
  `.dates(from: Date, to: Date, includeTime: Bool)` formatting accordingly.
- `StatsFilter`: recursive enum with custom `Encodable` producing the
  heterogeneous arrays:
  - `.is(Dimension, [String])`, `.isNot`, `.contains`, `.containsNot`,
    `.matches`, `.matchesNot` → `[op, dimension, clauses]`
  - case-insensitive variants via an options overload appending
    `{"case_sensitive": false}` as the 4th element
  - `.and([StatsFilter])`, `.or([StatsFilter])`, `.not(StatsFilter)` (encodes
    the child wrapped in a 1-element array)
  - `.hasDone(StatsFilter)`, `.hasNotDone(StatsFilter)`
  - `.segment(Int)` → `["is", "segment", [id]]`
- `OrderBy`: struct `{ target: String, direction: SortDirection }` where
  `SortDirection` is `asc`/`desc`; encodes as `[target, "asc"]`. Convenience
  inits from `Metric` and `Dimension`.
- `Include`: `{ imports: Bool?, timeLabels: Bool?, totalRows: Bool? }` with
  snake_case coding keys.
- `Pagination`: `{ limit: Int?, offset: Int? }`.

Response:

```swift
public struct StatsResponse: Decodable, Sendable {
    public let results: [Row]
    public let meta: Meta
    public let query: JSONValue?    // echoed, backend-transformed

    public struct Row: Decodable, Sendable, Equatable {
        public let metrics: [MetricValue]
        public let dimensions: [String]
    }

    public struct Meta: Decodable, Sendable {
        public let importsIncluded: Bool?
        public let importsSkipReason: String?
        public let importsWarning: String?
        public let timeLabels: [String]?
        public let totalRows: Int?
        public let metricWarnings: [String: MetricWarning]?
    }
}
```

`MetricValue`: single-value enum/struct decoding number or null (`.number(Double)`
/ `.null`), with `doubleValue: Double?` and `intValue: Int?` accessors. Metrics
rows mix ints, floats, and nulls; do not force `Double` decode failure on null.

### Sites API

All under `/api/v1/sites...`, bearer auth. List endpoints use cursor
pagination: responses are `{"sites": [...], "meta": {"after": ..., "before": ..., "limit": n}}`
(key varies per endpoint: `sites`, `teams`, `goals`, `guests`, `custom_props`).

```swift
public struct SitesAPI: Sendable {
    public func list(_ query: CursorQuery = .init()) async throws -> SiteList
    public func create(_ request: CreateSiteRequest) async throws -> Site
    public func get(siteID: String) async throws -> Site
    public func update(siteID: String, _ request: UpdateSiteRequest) async throws -> Site
    public func delete(siteID: String) async throws -> DeletedResponse

    public func teams(_ query: CursorQuery = .init()) async throws -> TeamList
    public func findOrCreateSharedLink(siteID: String, name: String) async throws -> SharedLink

    public func goals(siteID: String, _ query: CursorQuery = .init()) async throws -> GoalList
    public func findOrCreateGoal(_ request: GoalRequest) async throws -> Goal
    public func deleteGoal(goalID: Int, siteID: String) async throws -> DeletedResponse

    public func customProperties(siteID: String) async throws -> [CustomProperty]
    public func enableCustomProperty(siteID: String, property: String) async throws
    public func disableCustomProperty(siteID: String, property: String) async throws

    public func guests(siteID: String, _ query: CursorQuery = .init()) async throws -> GuestList
    public func findOrCreateGuest(siteID: String, email: String, role: GuestRole) async throws -> Guest
    public func removeGuest(siteID: String, email: String) async throws -> DeletedResponse
}
```

Models (explicit CodingKeys, snake_case wire names):

- `Site`: `domain`, `timezone`, optional `customProperties`,
  `trackerScriptConfiguration` (decode as `JSONValue?` — upstream shape is
  evolving; do not hard-model it in v1).
- `CreateSiteRequest`: `domain` (required), `timezone?`, `teamID?`.
- `UpdateSiteRequest`: `domain?`.
- `CursorQuery`: `after?`, `before?`, `limit?`, `teamID?` → query items.
- `SharedLink`: `name`, `url`.
- `Goal`: `id` (Int), `goalType` (`"event"`/`"page"` as a raw-representable
  `GoalType`), `displayName?`, `eventName?`, `pagePath?`.
- `GoalRequest`: `siteID`, `goalType`, `eventName?` / `pagePath?`,
  `displayName?`.
- `GuestRole`: `viewer` / `editor`. `Guest`: `email`, `role`, `status`.
- `DeletedResponse`: `{ deleted: Bool }` — upstream returns the string
  `"true"`; decode Bool or String leniently.
- `Team`: `id`, `name`, `apiAvailable`.
- List wrappers: `SiteList { sites, meta }`, etc., with
  `PaginationMeta { after: String?, before: String?, limit: Int }`.

DELETE endpoints that require parameters send them as a JSON body
(`{"site_id": ...}`) per the docs; `removeGuest` uses a query param.

### `PlausibleTrackerClient`

```swift
public actor PlausibleTrackerClient {
    public init(configuration: PlausibleConfiguration = .init(), domain: String)

    @discardableResult
    public func send(_ event: EventRequest) async throws -> EventResponse

    @discardableResult
    public func pageview(
        url: String, referrer: String? = nil,
        props: [String: EventPropertyValue]? = nil
    ) async throws -> EventResponse

    @discardableResult
    public func event(
        name: String, url: String, referrer: String? = nil,
        props: [String: EventPropertyValue]? = nil,
        revenue: Revenue? = nil, interactive: Bool? = nil
    ) async throws -> EventResponse
}
```

`POST /api/event`, auth `.none`, `Content-Type: application/json`.

Models:

```swift
public struct EventRequest: Encodable, Sendable {
    public var domain: String        // defaulted from the client's domain
    public var name: String          // "pageview" for pageviews
    public var url: String
    public var referrer: String?
    public var props: [String: EventPropertyValue]?   // max 30 pairs upstream
    public var revenue: Revenue?
    public var interactive: Bool?
    // transport hints, not encoded into the JSON body:
    public var userAgent: String?        // overrides configuration.userAgent
    public var forwardedFor: String?     // X-Forwarded-For
}

public enum EventPropertyValue: Encodable, Sendable, Equatable {
    case string(String), int(Int), double(Double), bool(Bool)
    // + ExpressibleBy{String,Integer,Float,Boolean}Literal
}

public struct Revenue: Codable, Sendable, Equatable {
    public var currency: String   // ISO 4217
    public var amount: Decimal    // encode as string to avoid float drift
}

public struct EventResponse: Sendable, Equatable {
    public let statusCode: Int
    public let droppedCount: Int  // x-plausible-dropped header value, 0 if absent
    public var dropped: Bool { droppedCount > 0 }
}
```

Tracker rules:

- The event body encoder must skip the transport-hint fields (`userAgent`,
  `forwardedFor`) — explicit `CodingKeys`.
- `EventRequest.pageview(...)`/`.event(...)` static factories mirror the client
  conveniences.
- Response handling: any 2xx is success; parse `x-plausible-dropped` header
  case-insensitively. Do not require a decodable body (`202 {}` or empty).
- The client sends `User-Agent` from the request override, else configuration.
  Document clearly that Plausible derives unique visitors from UA + IP, so
  servers relaying app events should set `forwardedFor` to the end user's IP.
- Trailing convenience: `interactive: false` excludes the event from bounce
  rate calculations.

## Concurrency and Thread Safety

- `PlausibleAPIClient` and all sub-APIs are `Sendable` structs.
- `PlausibleTrackerClient` is an `actor`.
- Everything public is `Sendable`; the package builds warning-free in Swift 6
  strict concurrency.

## Testing Strategy

XCTest, single `PlausibleTests` target, mirroring `UmamiTests` style: an actor
`RequestRecorder` + `PlausibleHTTPExecutor` closure stub. Required coverage:

- transport: bearer key injection, User-Agent, base URL + path resolution,
  JSON body round-trip
- error decoding: `{"error": "..."}` → `.api`, garbage body → `.unexpectedStatus`
- StatsQuery encoding fixtures (compare against exact JSON via
  `JSONSerialization` and sorted-keys encoding):
  - shortcut and custom `date_range`
  - each filter operator, nested `and`/`or`/`not`, `has_done`, segment,
    case-insensitivity modifier
  - `order_by` tuple encoding, `include`, `pagination`, custom-prop dimension
- StatsResponse decoding: mixed int/float/null metric values, meta fields,
  time labels
- Sites: request paths/methods/queries for list/create/get/update/delete,
  goal and guest flows, DELETE-with-body, `DeletedResponse` accepting `"true"`
  string and `true` bool
- Tracker: pageview and custom event body shape, props limit not enforced
  client-side, revenue amount encoded as string, `x-plausible-dropped` parsing,
  User-Agent and X-Forwarded-For header injection, 202-empty-body handling

## Versioning Strategy

- Semantic versioning over the Swift surface, starting 0.1.0.
- Record which Plausible docs snapshot (fetch date) each release was validated
  against.

## Decisions

- Package name is `Plausible`, repo `swift-plausible`.
- Raw-representable structs (not frozen enums) for server-defined vocabularies
  (metrics, dimensions, goal types, roles).
- Stats v1 API is not supported.
- Tracker client requires `domain` at init; per-event override allowed via
  `EventRequest`.
- Upstream source is checked in as the `refs/plausible` submodule; the docs are
  the primary contract and the source resolves ambiguity.
