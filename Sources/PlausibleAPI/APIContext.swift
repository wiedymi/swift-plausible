import Foundation
import PlausibleCore

struct PlausibleAPIContext: Sendable {
    let transport: any PlausibleTransport
    let auth: PlausibleAuth

    func withAuth(_ auth: PlausibleAuth) -> Self {
        Self(transport: transport, auth: auth)
    }
}
