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
        print("PASS safe diagnostic context fields and endpoint rejection")
    }
}
