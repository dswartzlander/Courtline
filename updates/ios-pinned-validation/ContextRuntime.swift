import Foundation
@main struct ContextRuntime {
    static func main() {
        precondition(SafeDiagnosticContext.field("CourtLine Pinned Test") == "CourtLine Pinned Test")
        for bad in ["a\nb", "a\n", "a\r", "token=secret", "https://a", "é", String(repeating: "a", count: 129)] {
            precondition(SafeDiagnosticContext.field(bad) == "unavailable")
        }
        precondition(SafeDiagnosticContext.field(nil) == "unavailable")
        precondition(SafeDiagnosticContext.endpoint(URL(string: "https://192.168.10.107:18200")!) == "https://192.168.10.107:18200")
        precondition(SafeDiagnosticContext.endpoint(URL(string: "https://host.local")!) == "https://host.local:443")
        for bad in ["http://192.168.1.1", "https://192.168.1.1/?key=secret", "https://u:secret@192.168.1.1", "https://example.com", "https://192.168.1.1/path"] {
            precondition(SafeDiagnosticContext.endpoint(URL(string: bad)!) == "unavailable")
        }
        precondition(SafeDiagnosticContext.booleanFlag(nil) == "absent")
        precondition(SafeDiagnosticContext.booleanFlag(true) == "true")
        precondition(SafeDiagnosticContext.booleanFlag(false) == "false")
        precondition(SafeDiagnosticContext.booleanFlag("true") == "invalid-type")
        precondition(SafeDiagnosticContext.booleanFlag(1) == "invalid-type")
        let config = SafeDiagnosticContext.privacyConfiguration([
            "NSLocalNetworkUsageDescription": "SECRET_DESCRIPTION",
            "NSAppTransportSecurity": ["NSAllowsLocalNetworking": true, "NSAllowsArbitraryLoads": false,
                "NSExceptionDomains": ["SECRET_DOMAIN": ["SECRET_KEY": "SECRET_VALUE"]]],
            "SECRET_OTHER": "SECRET_VALUE"
        ])
        precondition(config.contains("present-nonempty"))
        precondition(config.contains("NSAllowsLocalNetworking=true"))
        precondition(config.contains("NSAllowsArbitraryLoads=false"))
        precondition(config.contains("NSAllowsArbitraryLoadsInWebContent=absent"))
        precondition(!config.contains("SECRET"))
        precondition(SafeDiagnosticContext.privacyConfiguration([:]).contains("description: absent"))
        precondition(SafeDiagnosticContext.privacyConfiguration(["NSLocalNetworkUsageDescription": "  "]).contains("description: empty"))
        precondition(SafeDiagnosticContext.privacyConfiguration(["NSLocalNetworkUsageDescription": 7]).contains("description: invalid-type"))
        precondition(SafeDiagnosticContext.privacyConfiguration(["NSAppTransportSecurity": "SECRET"]).contains("dictionary: invalid-type"))
        print("PASS safe diagnostic context fields and endpoint rejection")
    }
}
