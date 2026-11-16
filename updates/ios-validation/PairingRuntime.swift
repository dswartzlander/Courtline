// CI-only exact shipping broker test. Fake transport handles ALL requests; no network or persistence.
private final class PairStub: URLProtocol {
    static var transportCode:Int? = nil
    static var probeState="notAvailable"
    static var probeCount=0
    static var invalidate=false
    static var status=200
    static var payload:Data = Data("{}".utf8)
    override class func canInit(with request:URLRequest)->Bool {true}
    override class func canonicalRequest(for request:URLRequest)->URLRequest {request}
    override func startLoading() {
        if let code=Self.transportCode {client?.urlProtocol(self,didFailWithError:NSError(domain:NSURLErrorDomain,code:code,userInfo:[NSLocalizedDescriptionKey:"SECRET_URL_en_"+String(repeating:"a",count:64)]));return}
        let r=HTTPURLResponse(url:request.url!,statusCode:Self.status,httpVersion:nil,headerFields:nil)!
        client?.urlProtocol(self,didReceive:r,cacheStoragePolicy:.notAllowed);client?.urlProtocol(self,didLoad:Self.payload);client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
extension CourtlineSessionBroker {
    fileprivate func pairingTestSetup() {
        origin=nil;viewerKey="";mainKey="";ready=false;revoked=false
        let c=URLSessionConfiguration.ephemeral;c.protocolClasses=[PairStub.self]
        network=URLSession(configuration:c,delegate:self,delegateQueue:nil)
        pathProbe={ [weak self] host,done in
            precondition(host.absoluteString=="http://10.0.0.2:3999")
            PairStub.probeCount += 1
            if PairStub.invalidate {self?.clearControl()}
            done(PairStub.probeState)
        }
    }
}
@main struct PairingRuntime {
 static func test(_ code:Int?,_ status:Int=200,_ body:String="{}",_ expected:String) {
    PairStub.transportCode=code;PairStub.status=status;PairStub.payload=Data(body.utf8)
    PairStub.probeCount=0
    let b=CourtlineSessionBroker();b.pairingTestSetup();var complete=false
    b.enroll("http://10.0.0.2:3999/api/stats?key=en_"+String(repeating:"a",count:64)){error in
       let actual=error?.localizedDescription ?? ""
       if expected.hasPrefix("PAIR_OFFLINE_DETAIL:") {
          precondition(actual.hasPrefix(expected+":"),"Unexpected pathdiagnostic "+actual)
          precondition(actual.range(of:"^PAIR_OFFLINE_DETAIL:[a-zA-Z]+:[01]:[01]:[01]:[01]$",options:.regularExpression) != nil)
       } else {precondition(actual==expected,"Expected "+expected+" got "+actual)}
       precondition(PairStub.probeCount == (code == -1009 ? 1:0),"Probe only after -1009");precondition(!b.ready && b.role=="viewer");complete=true
    }
    let deadline=Date().addingTimeInterval(10)
    while !complete && Date()<deadline {RunLoop.main.run(until:Date().addingTimeInterval(0.01))}
    precondition(complete);print("PASS "+expected)
 }
 static func main() {
   test(-1001,200,"{}","PAIR_TIMEOUT");for state in ["ready","localNetworkDenied","wifiDenied","cellularDenied","notAvailable","unavailable","cancelled","timeout"] {
      PairStub.probeState=state;test(-1009,200,"{}","PAIR_OFFLINE_DETAIL:"+state)
   }
   PairStub.probeState="secret_en_"+String(repeating:"a",count:64);test(-1009,200,"{}","PAIR_OFFLINE_DETAIL:unavailable")
   PairStub.invalidate=true;test(-1009,200,"{}","PAIR_CHANGED");PairStub.invalidate=false;test(-1004,200,"{}","PAIR_CONNECT");test(-1022,200,"{}","PAIR_TRANSPORT_POLICY");test(-1020,200,"{}","PAIR_LOCAL_NETWORK");test(-1003,200,"{}","PAIR_NETWORK")
   test(nil,403,"{\"code\":\"enrollment_invalid\",\"error\":\"secret\"}","PAIR_EXPIRED")
   test(nil,500,"{\"error\":\"secret\"}","PAIR_BACKEND_REJECTED")
   test(nil,200,"{}","PAIR_RESPONSE_INVALID");test(nil,200,"not json secret","PAIR_RESPONSE_INVALID")
 }
}
