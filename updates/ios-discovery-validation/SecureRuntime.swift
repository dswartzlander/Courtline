// Concatenated with the exact shipping SecureBackend and Broker sources.
// URLProtocol replaces ALL HTTP; never contacts a LAN or persists Keychain data.
private final class SecureStub:URLProtocol {
    static var seen:[URLRequest]=[]
    static var pending:SecureStub?
    static var hold=false
    static var wrongID=false
    static var reject=false
    static let id="11111111-1111-4111-8111-111111111111"
    static let family="22222222-2222-4222-8222-222222222222"
    override class func canInit(with request:URLRequest)->Bool{true}
    override class func canonicalRequest(for request:URLRequest)->URLRequest{request}
    override func startLoading(){Self.seen.append(request);if Self.hold{Self.pending=self}else{respond()}}
    override func stopLoading(){}
    func respond(){
        let identity=request.url!.path=="/api/server-identity"
        let r:[String:Any]=identity ? ["version":1,"backendId":Self.wrongID ? Self.family:Self.id]:["role":"viewer","deviceId":"session_"+Self.family,"sessionId":Self.family,"viewerKey":"ds_"+String(repeating:"b",count:64),"perDeviceControlPINs":true,"controlAllowed":true,"pinAvailable":true]
        client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:Self.reject ? 403:200,httpVersion:nil,headerFields:nil)!,cacheStoragePolicy:.notAllowed)
        client?.urlProtocol(self,didLoad:try! JSONSerialization.data(withJSONObject:r));client?.urlProtocolDidFinishLoading(self)
    }
}
extension CourtlineSessionBroker {
    fileprivate func testSetup(_ paired:Bool=false){
        origin=paired ? URL(string:"http://192.168.1.2:18100"):nil;viewerKey=paired ? "ds_"+String(repeating:"b",count:64):"";deviceID=paired ? "session_"+SecureStub.family:"";backendTrust=nil;ready=paired;revoked=false
        testPersist={_,_,_,_ in SecureRuntime.saves += 1}
    }
    fileprivate var pairedSecure:Bool{backendTrust != nil && origin?.scheme=="https"}
}
@main struct SecureRuntime {
 static var saves=0,checks=0
 static func check(_ condition:Bool,_ message:String){precondition(condition,message);checks += 1}
 static func wait(_ condition:()->Bool){let until=Date().addingTimeInterval(5);while !condition() && Date()<until{RunLoop.main.run(until:Date().addingTimeInterval(0.01))};check(condition(),"Completion bounded")}
 static func qr(_ purpose:String="migrate",_ modifications:[String:Any]=[:])->String {
    var j:[String:Any]=["type":"courtline-secure","version":1,"purpose":purpose,"backendId":SecureStub.id,"origin":"https://192.168.1.2:18101","certificateSha256":String(repeating:"a",count:64)]
    if purpose=="enroll"{j["enrollmentKey"]="en_"+String(repeating:"c",count:64)}
    modifications.forEach{j[$0.key]=$0.value};return String(data:try! JSONSerialization.data(withJSONObject:j),encoding:.utf8)!
 }
 static func fresh(_ paired:Bool=false)->CourtlineSessionBroker {SecureStub.seen=[];SecureStub.pending=nil;SecureStub.hold=false;SecureStub.wrongID=false;SecureStub.reject=false;saves=0;let b=CourtlineSessionBroker();b.testSetup(paired);return b}
 static func main(){
    PinnedBackendRequest.testProtocols=[SecureStub.self]
    check(SecureBackendQR(qr()) != nil,"migration parses")
    check(SecureBackendQR(qr("enroll")) != nil,"enrollment parses")
    for edits:[String:Any] in [["origin":"http://192.168.1.2:18100"],["origin":"https://example.com:18101"],["origin":"https://192.168.1.2:18101?key=bad"],["backendId":"bad"],["certificateSha256":"abc"],["enrollmentKey":"en_bad"],["purpose":"main"],["version":2]] {check(SecureBackendQR(qr("migrate",edits))==nil,"unsafe QR rejected")}
    func der(_ tag:UInt8,_ bytes:[UInt8])->[UInt8]{[tag,UInt8(bytes.count)]+bytes}
    func dates(_ a:String,_ b:String,_ tag:UInt8=0x18)->Data {let validity=der(0x30,der(tag,Array(a.utf8))+der(tag,Array(b.utf8)));return Data(der(0x30,der(0x30,[0x02,1,1,0x30,0,0x30,0]+validity)))}
    check(BackendCertificateDates.valid(dates("20200101000000Z","20300101000000Z")),"current dates valid")
    check(!BackendCertificateDates.valid(dates("20000101000000Z","20010101000000Z")),"expired rejected")
    check(!BackendCertificateDates.valid(dates("20400101000000Z","20410101000000Z")),"future rejected")
    check(!BackendCertificateDates.valid(dates("20209901000000Z","20300101000000Z")),"invalid calendar rejected")
    check(BackendCertificateDates.valid(dates("500101000000Z","490101000000Z",0x17)),"UTC1950 to2049 pivot")
    check(!BackendCertificateDates.valid(dates("20200101000000Z","20300101000000Z").dropLast()),"truncated rejected")
    check(!BackendCertificateDates.valid(Data()),"empty certificate rejected")
    check(!BackendCertificateDates.valid(Data([0x30,0x80,0,0])),"indefinite DER rejected")
    do {let b=fresh(true);var finished=false;var error:Error?;b.enroll(qr()){error=$0;finished=true};wait{finished};check(error==nil && b.pairedSecure && b.ready && b.role=="viewer" && saves==1,"migration commits once")
        check(SecureStub.seen.count==2,"identity then reopen only");check(SecureStub.seen[0].value(forHTTPHeaderField:"X-Courtline-Key")==nil,"identity no secret");check(SecureStub.seen[1].value(forHTTPHeaderField:"X-Courtline-Key")?.hasPrefix("ds_")==true,"registered key only after identity")
        var bad=false;b.enroll("http://192.168.1.2:18100/api/stats?key=en_"+String(repeating:"c",count:64)){bad=$0 != nil};check(bad && SecureStub.seen.count==2,"no HTTP fallback")
    }
    do {let b=fresh(true);SecureStub.wrongID=true;var finished=false;b.enroll(qr()){check($0 != nil,"wrong identity error");finished=true};wait{finished};check(saves==0 && SecureStub.seen.count==1 && !b.pairedSecure,"wrong ID never receives credential")}
    for resume in [false,true] {let b=fresh(true);SecureStub.hold=true;var finished=false;b.enroll(qr()){check($0 != nil,"cancel error");finished=true};wait{SecureStub.pending != nil};b.setForeground(false);if resume{b.setForeground(true)};wait{finished};check(saves==0 && SecureStub.seen.count==1 && !b.pairedSecure,"background generation cannot commit")}
    do {let b=fresh(true);b.setForeground(false);var failed=false;b.enroll(qr()){failed=$0 != nil};check(failed && SecureStub.seen.isEmpty,"background admission zero HTTP")}
    do {let b=fresh();var failed=false;b.enroll(qr()){failed=$0 != nil};check(failed && SecureStub.seen.isEmpty,"unpaired migration denied")}
    do {let b=fresh(true);var failed=false;b.enroll(qr("enroll")){failed=$0 != nil};check(failed && SecureStub.seen.isEmpty,"registered enrollment no duplicates")}
    do {let b=fresh();var finished=false;b.enroll(qr("enroll")){check($0==nil,"new enroll succeeds");finished=true};wait{finished};check(b.pairedSecure && b.role=="viewer" && saves==1,"new enrolled Companion");check(SecureStub.seen[1].value(forHTTPHeaderField:"X-Courtline-Key")?.hasPrefix("en_")==true,"enrollment credential scoped")}
    print("PASS \(checks) secure QR and broker fake-network checks; real TLS/mDNS/device testing still required")
 }
}
