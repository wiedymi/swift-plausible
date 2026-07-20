# Plausible

[![GitHub](https://img.shields.io/badge/-GitHub-181717?style=flat-square&logo=github&logoColor=white)](https://github.com/wiedymi)
[![Twitter](https://img.shields.io/badge/-Twitter-1DA1F2?style=flat-square&logo=twitter&logoColor=white)](https://x.com/wiedymi)
[![Email](https://img.shields.io/badge/-Email-EA4335?style=flat-square&logo=gmail&logoColor=white)](mailto:contact@wiedymi.com)
[![Discord](https://img.shields.io/badge/-Discord-5865F2?style=flat-square&logo=discord&logoColor=white)](https://discord.gg/zemMZtrkSb)
[![Support me](https://img.shields.io/badge/-Support%20me-ff69b4?style=flat-square&logo=githubsponsors&logoColor=white)](https://github.com/sponsors/vivy-company)

Swift SDK for the Plausible Analytics API, focused on Apple-platform dashboard apps and event tracking.

Use it to build native iOS/macOS analytics dashboards with the Stats API v2 and Sites API, with Events API ingestion included for pageviews and custom events.

## Features

- Apple-only Swift Package with Swift Concurrency-first API
- Public `import Plausible` surface with split modules underneath:
  - `PlausibleCore`
  - `PlausibleAPI`
  - `PlausibleTracker`
- Stats API v2 support:
  - typed metrics and dimensions
  - custom date ranges
  - simple, logical, behavioral, and segment filters
  - ordering, includes, and pagination
- Sites API support:
  - sites and teams
  - shared links
  - goals
  - custom properties
  - guests
- Tracker support:
  - pageviews
  - custom events and properties
  - revenue and non-interactive events
  - dropped-event detection
- Raw API escape hatch for upstream routes not yet wrapped

## Platforms

- iOS 15+
- macOS 12+
- tvOS 15+
- watchOS 8+
- visionOS 1+
- Swift tools 6.0+

## Installation

Add to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/wiedymi/swift-plausible.git", from: "0.1.0")
]
```

Then add the library target:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "Plausible", package: "swift-plausible")
    ]
)
```

## Quick Start

### Dashboard client

```swift
import Foundation
import Plausible

let configuration = PlausibleConfiguration(
    baseURL: URL(string: "https://plausible.io")!,
    userAgent: "MyDashboard/1.0"
)

let client = PlausibleAPIClient(
    configuration: configuration,
    auth: .apiKey("your-stats-api-key")
)

let response = try await client.stats.query(
    .init(
        siteID: "example.com",
        metrics: [.visitors, .pageviews, .bounceRate],
        dateRange: .last30Days,
        dimensions: [.timeDay],
        include: .init(timeLabels: true)
    )
)

for row in response.results {
    print(row.dimensions, row.metrics)
}
```

### Tracker client

```swift
import Foundation
import Plausible

let tracker = PlausibleTrackerClient(domain: "example.com")

try await tracker.pageview(url: "https://example.com/pricing")

try await tracker.event(
    name: "Purchase",
    url: "https://example.com/checkout",
    props: ["plan": "team", "seats": 5],
    revenue: .init(currency: "USD", amount: Decimal(string: "99.00")!)
)
```

## Development

```bash
swift build
swift test
```

## Docs

- `SPEC.md` - SDK scope and implementation plan
- `refs/plausible` - upstream Plausible source included as a git submodule for reference
- [Plausible Stats API](https://plausible.io/docs/stats-api)
- [Plausible Sites API](https://plausible.io/docs/sites-api)
- [Plausible Events API](https://plausible.io/docs/events-api)

## Notes

- `baseURL` defaults to `https://plausible.io`; set it to your self-hosted Plausible server origin when needed.
- Stats and Sites requests use bearer API keys, while Events API requests are unauthenticated.
- Plausible derives unique visitors from the `User-Agent` and client IP. Servers relaying app events should set `EventRequest.forwardedFor` to the end user's IP.
- Set `interactive: false` on a custom event to exclude it from bounce-rate calculations.
- API contracts were validated against the Plausible documentation on July 20, 2026, and the upstream commit pinned in `SPEC.md`.

## License

MIT
