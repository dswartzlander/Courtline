// CI-only exact shipping broker test. Fake transport handles ALL requests; no network or persistence.
private final class PairStub: URLProtocol {
    static var transportCode:Int? = nil
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
    }
}
@main struct PairingRuntime {
 static func test(_ code:Int?,_ status:Int=200,_ body:String="{}",_ expected:String) {
    PairStub.transportCode=code;PairStub.status=status;PairStub.payload=Data(body.utf8)
    let b=CourtlineSessionBroker();b.pairingTestSetup();var complete=false
    b.enroll("http://10.0.0.2:3999/api/stats?key=en_"+String(repeating:"a",count:64)){error in
       precondition(error?.localizedDescription==expected,"Expected "+expected+" got "+String(describing:error));precondition(!b.ready && b.role=="viewer");complete=true
    }
    let deadline=Date().addingTimeInterval(10)
    while !complete && Date()<deadline {RunLoop.main.run(until:Date().addingTimeInterval(0.01))}
    precondition(complete);print("PASS "+expected)
 }
 static func main() {
   test(-1001,200,"{}","PAIR_TIMEOUT");test(-1009,200,"{}","PAIR_OFFLINE");test(-1004,200,"{}","PAIR_CONNECT");test(-1022,200,"{}","PAIR_TRANSPORT_POLICY");test(-1020,200,"{}","PAIR_LOCAL_NETWORK");test(-1003,200,"{}","PAIR_NETWORK")
   test(nil,403,"{\"code\":\"enrollment_invalid\",\"error\":\"secret\"}","PAIR_EXPIRED")
   test(nil,500,"{\"error\":\"secret\"}","PAIR_BACKEND_REJECTED")
   test(nil,200,"{}","PAIR_RESPONSE_INVALID");test(nil,200,"not json secret","PAIR_RESPONSE_INVALID")
 }
}
