import Foundation
import PlausibleCore

public struct StatsAPI: Sendable {
    let context: PlausibleAPIContext

    public func query(_ query: StatsQuery) async throws -> StatsResponse {
        try await context.transport.send(
            .json(
                method: "POST",
                path: "/api/v2/query",
                auth: context.auth,
                body: .json(query)
            )
        )
    }
}
