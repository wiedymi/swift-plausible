import Foundation
import XCTest
import Plausible

final class PlausibleTests: XCTestCase {
    func testDecoderHandlesSupportedDateFormats() throws {
        struct Payload: Decodable {
            let date: Date
        }

        let decoder = JSONDecoder.plausibleDefault()
        let dateOnly = try decoder.decode(Payload.self, from: Data(#"{"date":"2026-07-20"}"#.utf8))
        let basic = try decoder.decode(Payload.self, from: Data(#"{"date":"2026-07-20T12:30:00Z"}"#.utf8))
        let fractional = try decoder.decode(Payload.self, from: Data(#"{"date":"2026-07-20T12:30:00.123Z"}"#.utf8))

        XCTAssertEqual(dateOnly.date.timeIntervalSince1970, 1_784_505_600)
        XCTAssertEqual(basic.date.timeIntervalSince1970, 1_784_550_600)
        XCTAssertEqual(fractional.date.timeIntervalSince1970, 1_784_550_600.123, accuracy: 0.001)
    }

    func testTransportInjectsBearerUserAgentResolvesPathAndRoundTripsJSON() async throws {
        struct Body: Codable, Sendable, Equatable {
            let siteID: String

            enum CodingKeys: String, CodingKey {
                case siteID = "site_id"
            }
        }

        let recorder = RequestRecorder()
        let configuration = makeConfiguration(userAgent: "PlausibleTests/1.0", recorder: recorder) { _ in
            Self.response(statusCode: 200, body: #"{"site_id":"example.com"}"#)
        }
        let client = PlausibleAPIClient(configuration: configuration, auth: .apiKey("secret-key"))
        let response = try await client.raw.post(path: "/api/future", body: Body(siteID: "example.com"))

        XCTAssertEqual(
            try response.decodeJSON(),
            .object(["site_id": .string("example.com")])
        )

        let request = await recorder.request(at: 0)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://analytics.example.com/api/future")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "PlausibleTests/1.0")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        try assertJSONEqual(request.httpBody, #"{"site_id":"example.com"}"#)
    }

    func testTransportMapsAPIAndUnexpectedErrors() async throws {
        let apiConfiguration = makeConfiguration { _ in
            Self.response(statusCode: 401, body: #"{"error":"Invalid API key"}"#)
        }
        let apiClient = PlausibleAPIClient(configuration: apiConfiguration)

        do {
            _ = try await apiClient.raw.get(path: "/api/future")
            XCTFail("Expected API error")
        } catch let error as PlausibleTransportError {
            guard case .api(let body, let statusCode) = error else {
                return XCTFail("Expected mapped API error, got \(error)")
            }
            XCTAssertEqual(body.message, "Invalid API key")
            XCTAssertNil(body.fieldErrors)
            XCTAssertEqual(statusCode, 401)
        }

        let fieldErrorConfiguration = makeConfiguration { _ in
            Self.response(
                statusCode: 400,
                body: #"{"errors":{"url":["is required","must be absolute"],"domain":["is invalid"]}}"#
            )
        }
        let fieldErrorClient = PlausibleAPIClient(configuration: fieldErrorConfiguration)

        do {
            _ = try await fieldErrorClient.raw.get(path: "/api/future")
            XCTFail("Expected field-validation API error")
        } catch let error as PlausibleTransportError {
            guard case .api(let body, let statusCode) = error else {
                return XCTFail("Expected mapped field-validation API error, got \(error)")
            }
            XCTAssertEqual(body.message, "domain: is invalid; url: is required, must be absolute")
            XCTAssertEqual(
                body.fieldErrors,
                ["domain": ["is invalid"], "url": ["is required", "must be absolute"]]
            )
            XCTAssertEqual(statusCode, 400)
        }

        let garbageConfiguration = makeConfiguration { _ in
            Self.response(statusCode: 500, body: "not-json")
        }
        let garbageClient = PlausibleAPIClient(configuration: garbageConfiguration)

        do {
            _ = try await garbageClient.raw.get(path: "/api/future")
            XCTFail("Expected unexpected-status error")
        } catch let error as PlausibleTransportError {
            guard case .unexpectedStatus(let statusCode) = error else {
                return XCTFail("Expected unexpected status, got \(error)")
            }
            XCTAssertEqual(statusCode, 500)
        }
    }

    func testStatsQueryEncodesShortcutAndOmitsEmptyCollections() throws {
        let query = StatsQuery(
            siteID: "example.com",
            metrics: [.visitors, .viewsPerVisit],
            dateRange: .last7Days
        )

        try assertEncodedJSON(
            query,
            equals: #"{"date_range":"7d","metrics":["visitors","views_per_visit"],"site_id":"example.com"}"#
        )
    }

    func testStatsQueryEncodesCustomRangeFiltersOrderingIncludeAndPagination() throws {
        let filters: [StatsFilter] = [
            .is(.country, ["DE"]),
            .isNot(.city, ["Berlin"]),
            .contains(.eventPage, ["/docs"]),
            .containsNot(.referrer, ["internal"]),
            .matches(.eventPage, ["^/user/\\d+$"]),
            .matchesNot(.source, ["bot"]),
            .and([.is(.countryName, ["Germany"]), .is(.cityName, ["Berlin"])]),
            .or([.is(.browser, ["Safari"]), .is(.browser, ["Firefox"])]),
            .not(.is(.device, ["Desktop"])),
            .hasDone(.is(.eventGoal, ["Signup"])),
            .hasNotDone(.contains(.eventPage, ["/pricing"])),
            .segment(42),
            .contains(.eventProperty("logged_in"), ["TRUE"], options: .caseInsensitive),
        ]
        let query = StatsQuery(
            siteID: "example.com",
            metrics: [.visitors, .conversionRate],
            dateRange: .dates(from: "2026-01-01", to: "2026-01-31"),
            dimensions: [.eventProperty("logged_in"), .utm("source")],
            filters: filters,
            orderBy: [
                .init(.visitors, direction: .desc),
                .init(.utmSource, direction: .asc),
            ],
            include: .init(imports: true, timeLabels: false, totalRows: true),
            pagination: .init(limit: 50, offset: 100)
        )

        try assertEncodedJSON(
            query,
            equals: """
            {
              "site_id":"example.com",
              "metrics":["visitors","conversion_rate"],
              "date_range":["2026-01-01","2026-01-31"],
              "dimensions":["event:props:logged_in","visit:utm_source"],
              "filters":[
                ["is","visit:country",["DE"]],
                ["is_not","visit:city",["Berlin"]],
                ["contains","event:page",["/docs"]],
                ["contains_not","visit:referrer",["internal"]],
                ["matches","event:page",["^/user/\\\\d+$"]],
                ["matches_not","visit:source",["bot"]],
                ["and",[["is","visit:country_name",["Germany"]],["is","visit:city_name",["Berlin"]]]],
                ["or",[["is","visit:browser",["Safari"]],["is","visit:browser",["Firefox"]]]],
                ["not",["is","visit:device",["Desktop"]]],
                ["has_done",["is","event:goal",["Signup"]]],
                ["has_not_done",["contains","event:page",["/pricing"]]],
                ["is","segment",[42]],
                ["contains","event:props:logged_in",["TRUE"],{"case_sensitive":false}]
              ],
              "order_by":[["visitors","desc"],["visit:utm_source","asc"]],
              "include":{"imports":true,"time_labels":false,"total_rows":true},
              "pagination":{"limit":50,"offset":100}
            }
            """
        )
    }

    func testDateRangeDateConvenienceEncodesDateAndTimestamp() throws {
        let from = Date(timeIntervalSince1970: 0)
        let to = Date(timeIntervalSince1970: 86_400)

        try assertEncodedJSON(DateRange.dates(from: from, to: to, includeTime: false), equals: #"["1970-01-01","1970-01-02"]"#)
        try assertEncodedJSON(DateRange.dates(from: from, to: to, includeTime: true), equals: #"["1970-01-01T00:00:00Z","1970-01-02T00:00:00Z"]"#)
    }

    func testStatsResponseDecodesMixedMetricValuesAndMeta() throws {
        let data = Data(
            """
            {
              "results":[{"metrics":[12,3.5,null],"dimensions":["2026-07-20"]}],
              "meta":{
                "imports_included":false,
                "imports_skip_reason":"unsupported_interval",
                "imports_warning":"Native stats only",
                "time_labels":["2026-07-20","2026-07-21"],
                "total_rows":2,
                "metric_warnings":{"total_revenue":{"code":"no_revenue_goals","warning":"No goals"}}
              },
              "query":{"site_id":"example.com"}
            }
            """.utf8
        )

        let response = try JSONDecoder.plausibleDefault().decode(StatsResponse.self, from: data)

        XCTAssertEqual(response.results[0].metrics, [.number(12), .number(3.5), .null])
        XCTAssertEqual(response.results[0].metrics[0].intValue, 12)
        XCTAssertNil(response.results[0].metrics[1].intValue)
        XCTAssertEqual(response.results[0].metrics[1].doubleValue, 3.5)
        XCTAssertNil(response.results[0].metrics[2].doubleValue)
        XCTAssertEqual(response.meta.importsIncluded, false)
        XCTAssertEqual(response.meta.importsSkipReason, "unsupported_interval")
        XCTAssertEqual(response.meta.importsWarning, "Native stats only")
        XCTAssertEqual(response.meta.timeLabels, ["2026-07-20", "2026-07-21"])
        XCTAssertEqual(response.meta.totalRows, 2)
        XCTAssertEqual(response.meta.metricWarnings?["total_revenue"]?.code, "no_revenue_goals")
        XCTAssertEqual(response.query, .object(["site_id": .string("example.com")]))
    }

    func testSitesRequestsCoverSiteTeamSharedLinkAndGoalFlows() async throws {
        let recorder = RequestRecorder()
        let configuration = makeConfiguration(recorder: recorder) { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/sites"):
                return Self.response(statusCode: 200, body: #"{"sites":[],"meta":{"after":null,"before":null,"limit":10}}"#)
            case ("POST", "/api/v1/sites"):
                return Self.response(statusCode: 200, body: Self.siteJSON(domain: "new.example.com"))
            case ("GET", "/api/v1/sites/example.com"):
                return Self.response(statusCode: 200, body: Self.siteJSON(domain: "example.com"))
            case ("PUT", "/api/v1/sites/example.com"):
                return Self.response(statusCode: 200, body: Self.siteJSON(domain: "renamed.example.com"))
            case ("DELETE", "/api/v1/sites/example.com"):
                return Self.response(statusCode: 200, body: #"{"deleted":"true"}"#)
            case ("GET", "/api/v1/sites/teams"):
                return Self.response(statusCode: 200, body: #"{"teams":[],"meta":{"after":null,"before":null,"limit":10}}"#)
            case ("PUT", "/api/v1/sites/shared-links"):
                return Self.response(statusCode: 200, body: #"{"name":"Public","url":"https://plausible.io/share/example.com"}"#)
            case ("GET", "/api/v1/sites/goals"):
                return Self.response(statusCode: 200, body: #"{"goals":[],"meta":{"after":null,"before":null,"limit":10}}"#)
            case ("PUT", "/api/v1/sites/goals"):
                return Self.response(statusCode: 200, body: #"{"id":"7","goal_type":"event","display_name":"Signup","event_name":"Signup","page_path":null,"custom_props":{"tier":"premium"}}"#)
            case ("DELETE", "/api/v1/sites/goals/7"):
                return Self.response(statusCode: 200, body: #"{"deleted":true}"#)
            default:
                return Self.response(statusCode: 404, body: #"{"error":"Unexpected route"}"#)
            }
        }
        let sites = PlausibleAPIClient(configuration: configuration, auth: .apiKey("sites-key")).sites

        _ = try await sites.list(.init(after: "next", before: "previous", limit: 10, teamID: "team-1"))
        _ = try await sites.create(.init(domain: "new.example.com", timezone: "Europe/London", teamID: "team-1"))
        _ = try await sites.get(siteID: "example.com")
        _ = try await sites.update(siteID: "example.com", .init(domain: "renamed.example.com"))
        let deleted = try await sites.delete(siteID: "example.com")
        _ = try await sites.teams(.init(limit: 10))
        _ = try await sites.findOrCreateSharedLink(siteID: "example.com", name: "Public")
        _ = try await sites.goals(siteID: "example.com", .init(after: "goal-next", limit: 10))
        let goal = try await sites.findOrCreateGoal(
            .init(
                siteID: "example.com",
                goalType: .event,
                eventName: "Signup",
                displayName: "Signup",
                customProps: ["tier": "premium"]
            )
        )
        let goalDeleted = try await sites.deleteGoal(goalID: 7, siteID: "example.com")

        XCTAssertTrue(deleted.deleted)
        XCTAssertEqual(goal.id, 7)
        XCTAssertEqual(goal.customProps, ["tier": "premium"])
        XCTAssertTrue(goalDeleted.deleted)

        let list = await recorder.request(at: 0)
        let create = await recorder.request(at: 1)
        let update = await recorder.request(at: 3)
        let delete = await recorder.request(at: 4)
        let sharedLink = await recorder.request(at: 6)
        let goals = await recorder.request(at: 7)
        let createGoal = await recorder.request(at: 8)
        let deleteGoal = await recorder.request(at: 9)
        XCTAssertEqual(queryDictionary(list), ["after": "next", "before": "previous", "limit": "10", "team_id": "team-1"])
        try assertJSONEqual(create.httpBody, #"{"domain":"new.example.com","timezone":"Europe/London","team_id":"team-1"}"#)
        XCTAssertEqual(update.httpMethod, "PUT")
        try assertJSONEqual(update.httpBody, #"{"domain":"renamed.example.com"}"#)
        XCTAssertEqual(delete.httpMethod, "DELETE")
        try assertJSONEqual(sharedLink.httpBody, #"{"site_id":"example.com","name":"Public"}"#)
        XCTAssertEqual(queryDictionary(goals), ["after": "goal-next", "limit": "10", "site_id": "example.com"])
        try assertJSONEqual(createGoal.httpBody, #"{"site_id":"example.com","goal_type":"event","event_name":"Signup","display_name":"Signup","custom_props":{"tier":"premium"}}"#)
        try assertJSONEqual(deleteGoal.httpBody, #"{"site_id":"example.com"}"#)
    }

    func testSitesRequestsCoverCustomPropertyAndGuestFlows() async throws {
        let recorder = RequestRecorder()
        let configuration = makeConfiguration(recorder: recorder) { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/sites/custom-props"):
                return Self.response(statusCode: 200, body: #"{"custom_properties":[{"property":"logged_in"}]}"#)
            case ("PUT", "/api/v1/sites/custom-props"):
                return Self.response(statusCode: 200, body: "")
            case ("DELETE", "/api/v1/sites/custom-props/logged_in"):
                return Self.response(statusCode: 200, body: #"{"deleted":true}"#)
            case ("GET", "/api/v1/sites/guests"):
                return Self.response(statusCode: 200, body: #"{"guests":[],"meta":{"after":null,"before":null,"limit":20}}"#)
            case ("PUT", "/api/v1/sites/guests"):
                return Self.response(statusCode: 200, body: #"{"email":"guest@example.com","role":"editor","status":"invited"}"#)
            case ("DELETE", "/api/v1/sites/guests/guest@example.com"):
                return Self.response(statusCode: 200, body: #"{"deleted":"true"}"#)
            default:
                return Self.response(statusCode: 404, body: #"{"error":"Unexpected route"}"#)
            }
        }
        let sites = PlausibleAPIClient(configuration: configuration, auth: .apiKey("sites-key")).sites

        let properties = try await sites.customProperties(siteID: "example.com")
        try await sites.enableCustomProperty(siteID: "example.com", property: "logged_in")
        try await sites.disableCustomProperty(siteID: "example.com", property: "logged_in")
        _ = try await sites.guests(siteID: "example.com", .init(before: "guest-prev", limit: 20))
        let guest = try await sites.findOrCreateGuest(siteID: "example.com", email: "guest@example.com", role: .editor)
        let removed = try await sites.removeGuest(siteID: "example.com", email: "guest@example.com")

        XCTAssertEqual(properties, [.init(property: "logged_in")])
        XCTAssertEqual(guest.role, .editor)
        XCTAssertTrue(removed.deleted)
        let listProperties = await recorder.request(at: 0)
        let enableProperty = await recorder.request(at: 1)
        let disableProperty = await recorder.request(at: 2)
        let listGuests = await recorder.request(at: 3)
        let createGuest = await recorder.request(at: 4)
        let removeGuest = await recorder.request(at: 5)
        XCTAssertEqual(queryDictionary(listProperties), ["site_id": "example.com"])
        try assertJSONEqual(enableProperty.httpBody, #"{"site_id":"example.com","property":"logged_in"}"#)
        XCTAssertEqual(disableProperty.httpMethod, "DELETE")
        try assertJSONEqual(disableProperty.httpBody, #"{"site_id":"example.com"}"#)
        XCTAssertEqual(queryDictionary(listGuests), ["before": "guest-prev", "limit": "20", "site_id": "example.com"])
        try assertJSONEqual(createGuest.httpBody, #"{"site_id":"example.com","email":"guest@example.com","role":"editor"}"#)
        XCTAssertEqual(queryDictionary(removeGuest), ["site_id": "example.com"])
    }

    func testDeletedResponseAcceptsBooleanAndString() throws {
        let decoder = JSONDecoder.plausibleDefault()
        XCTAssertEqual(try decoder.decode(DeletedResponse.self, from: Data(#"{"deleted":true}"#.utf8)), .init(deleted: true))
        XCTAssertEqual(try decoder.decode(DeletedResponse.self, from: Data(#"{"deleted":"true"}"#.utf8)), .init(deleted: true))
    }

    func testTrackerPageviewUsesConfigurationUserAgentAndEmpty202Body() async throws {
        let recorder = RequestRecorder()
        let configuration = makeConfiguration(userAgent: "App/1.0", recorder: recorder) { _ in
            Self.response(statusCode: 202, body: "")
        }
        let tracker = PlausibleTrackerClient(configuration: configuration, domain: "example.com")

        let response = try await tracker.pageview(
            url: "https://example.com/docs",
            referrer: "https://search.example",
            props: ["logged_in": true]
        )

        XCTAssertEqual(response, .init(statusCode: 202, droppedCount: 0))
        XCTAssertEqual(response.droppedCount, 0)
        XCTAssertFalse(response.dropped)
        let request = await recorder.request(at: 0)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/event")
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "App/1.0")
        try assertJSONEqual(
            request.httpBody,
            #"{"domain":"example.com","name":"pageview","url":"https://example.com/docs","referrer":"https://search.example","props":{"logged_in":true}}"#
        )
    }

    func testTrackerCustomEventAllowsLargePropsEncodesRevenueAndInjectsTransportHeaders() async throws {
        let recorder = RequestRecorder()
        let configuration = makeConfiguration(userAgent: "Default/1.0", recorder: recorder) { _ in
            Self.response(statusCode: 202, body: "{}", headers: ["X-Plausible-Dropped": "2"])
        }
        let tracker = PlausibleTrackerClient(configuration: configuration, domain: "default.example.com")
        let props = Dictionary(uniqueKeysWithValues: (0..<31).map { ("key_\($0)", EventPropertyValue.int($0)) })
        let event = EventRequest.event(
            domain: "override.example.com",
            name: "Purchase",
            url: "https://override.example.com/checkout",
            props: props,
            revenue: .init(currency: "USD", amount: Decimal(string: "1322.22")!),
            interactive: false,
            userAgent: "Override/2.0",
            forwardedFor: "203.0.113.10"
        )

        let response = try await tracker.send(event)

        XCTAssertEqual(response, .init(statusCode: 202, droppedCount: 2))
        XCTAssertEqual(response.droppedCount, 2)
        XCTAssertTrue(response.dropped)
        let request = await recorder.request(at: 0)
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "Override/2.0")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Forwarded-For"), "203.0.113.10")
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["domain"] as? String, "override.example.com")
        XCTAssertEqual(json["name"] as? String, "Purchase")
        XCTAssertEqual(json["interactive"] as? Bool, false)
        XCTAssertEqual((json["props"] as? [String: Any])?.count, 31)
        XCTAssertEqual((json["revenue"] as? [String: Any])?["amount"] as? String, "1322.22")
        XCTAssertNil(json["userAgent"])
        XCTAssertNil(json["forwardedFor"])
        XCTAssertNil(json["user_agent"])
        XCTAssertNil(json["forwarded_for"])
    }

    func testTrackerDefaultsUnparsableDroppedCountToZero() async throws {
        let configuration = makeConfiguration { _ in
            Self.response(
                statusCode: 202,
                body: "{}",
                headers: ["X-Plausible-Dropped": "not-a-number"]
            )
        }
        let tracker = PlausibleTrackerClient(configuration: configuration, domain: "example.com")

        let response = try await tracker.pageview(url: "https://example.com")

        XCTAssertEqual(response.droppedCount, 0)
        XCTAssertFalse(response.dropped)
    }

    private func makeConfiguration(
        userAgent: String? = nil,
        recorder: RequestRecorder? = nil,
        responder: @escaping @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)
    ) -> PlausibleConfiguration {
        let executor = PlausibleHTTPExecutor { request in
            if let recorder {
                await recorder.append(request)
            }
            return try responder(request)
        }

        return PlausibleConfiguration(
            baseURL: URL(string: "https://analytics.example.com")!,
            userAgent: userAgent,
            executor: executor
        )
    }

    private func assertEncodedJSON<Value: Encodable>(
        _ value: Value,
        equals expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let encoder = JSONEncoder.plausibleDefault()
        encoder.outputFormatting = [.sortedKeys]
        let actual = try encoder.encode(value)
        try assertJSONEqual(actual, expected, file: file, line: line)
    }

    private func assertJSONEqual(
        _ actual: Data?,
        _ expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let actual = try XCTUnwrap(actual, file: file, line: line)
        let actualObject = try JSONSerialization.jsonObject(with: actual)
        let expectedObject = try JSONSerialization.jsonObject(with: Data(expected.utf8))
        let actualSorted = try JSONSerialization.data(withJSONObject: actualObject, options: [.sortedKeys])
        let expectedSorted = try JSONSerialization.data(withJSONObject: expectedObject, options: [.sortedKeys])
        XCTAssertEqual(actualSorted, expectedSorted, file: file, line: line)
    }

    private func queryDictionary(_ request: URLRequest) -> [String: String] {
        guard let url = request.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }

    private static func response(
        statusCode: Int,
        body: String,
        headers: [String: String] = [:]
    ) -> (Data, HTTPURLResponse) {
        let url = URL(string: "https://analytics.example.com")!
        var allHeaders = ["Content-Type": "application/json"]
        allHeaders.merge(headers) { _, new in new }
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: allHeaders
        )!
        return (Data(body.utf8), response)
    }

    private static func siteJSON(domain: String) -> String {
        """
        {
          "domain":"\(domain)",
          "timezone":"Europe/London",
          "custom_properties":["logged_in"],
          "tracker_script_configuration":{"id":"pa-test"}
        }
        """
    }
}

actor RequestRecorder {
    private var requests: [URLRequest] = []

    func append(_ request: URLRequest) {
        requests.append(request)
    }

    func request(at index: Int) -> URLRequest {
        requests[index]
    }
}
