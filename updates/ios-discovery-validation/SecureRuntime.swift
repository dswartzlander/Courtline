// Concatenated with the exact shipping SecureBackend and Broker sources.
// URLProtocol replaces ALL HTTP; never contacts a LAN or persists Keychain data.
private final class SecureStub:URLProtocol {
    static var seen:[URLRequest]=[]
    static var bodies:[Data]=[]
    static var pending:SecureStub?
    static var hold=false
    static var holdRecovery=false
    static var wrongID=false
    static var reject=false
    static var wrongFamily=false
    static let id="11111111-1111-4111-8111-111111111111"
    static let family="22222222-2222-4222-8222-222222222222"
    override class func canInit(with request:URLRequest)->Bool{true}
    override class func canonicalRequest(for request:URLRequest)->URLRequest{request}
    override func startLoading(){Self.seen.append(request);
        if let data=request.httpBody {Self.bodies.append(data)} else if let stream=request.httpBodyStream {stream.open();defer{stream.close()};var data=Data();var buffer=[UInt8](repeating:0,count:1024);while stream.hasBytesAvailable{let count=stream.read(&buffer,maxLength:buffer.count);if count<=0{break};data.append(contentsOf:buffer.prefix(count))};Self.bodies.append(data)} else {Self.bodies.append(Data())};if Self.hold || (Self.holdRecovery && request.url?.path=="/api/device-session"){Self.pending=self}else{respond()}}
    override func stopLoading(){}
    func respond(){
        let identity=request.url!.path=="/api/server-identity"
        let r:[String:Any]=identity ? ["version":1,"backendId":Self.wrongID ? Self.family:Self.id]:["role":"viewer","deviceId":"session_"+(Self.wrongFamily ? Self.id:Self.family),"sessionId":Self.wrongFamily ? Self.id:Self.family,"viewerKey":"ds_"+String(repeating:"b",count:64),"perDeviceControlPINs":true,"controlAllowed":true,"pinAvailable":true]
        client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:Self.reject ? 403:200,httpVersion:nil,headerFields:nil)!,cacheStoragePolicy:.notAllowed)
        client?.urlProtocol(self,didLoad:try! JSONSerialization.data(withJSONObject:r));client?.urlProtocolDidFinishLoading(self)
    }
}
extension CourtlineSessionBroker {
    fileprivate func testSetup(_ paired:Bool=false){
        origin=paired ? URL(string:"http://192.168.1.2:18100"):nil;viewerKey=paired ? "ds_"+String(repeating:"b",count:64):"";deviceID=paired ? "session_"+SecureStub.family:"";backendTrust=nil;ready=paired;revoked=false
        testPersist={_,_,_,_ in SecureRuntime.saves += 1}
    }
    fileprivate func testStorageFailure(){testPersist={_,_,_,_ in throw NSError(domain:"TestStorage",code:1)}}
    fileprivate func testTrusted(){backendTrust=BackendTrust(backendId:SecureStub.id,certificateSha256:String(repeating:"a",count:64));origin=URL(string:"https://192.168.1.2:18101")}
    fileprivate var savedPin:String? {backendTrust?.certificateSha256}
    fileprivate var pairedSecure:Bool{backendTrust != nil && origin?.scheme=="https"}
}
@main struct SecureRuntime {
 static var saves=0,checks=0
 static func check(_ condition:Bool,_ message:String){precondition(condition,message);checks += 1}
 static func wait(_ condition:()->Bool){let until=Date().addingTimeInterval(5);while !condition() && Date()<until{RunLoop.main.run(until:Date().addingTimeInterval(0.01))};check(condition(),"Completion bounded")}
 static func qr(_ purpose:String="migrate",_ modifications:[String:Any]=[:])->String {
    var j:[String:Any]=["type":"courtline-secure","version":1,"purpose":purpose,"backendId":SecureStub.id,"origin":"https://192.168.1.2:18101","certificateSha256":String(repeating:"a",count:64)]
    if purpose=="enroll"{j["enrollmentKey"]="en_"+String(repeating:"c",count:64)}
    if purpose=="recover"{j["recoveryKey"]="rc_"+String(repeating:"d",count:64);j["sessionId"]=SecureStub.family;j["deviceName"]="Test tablet"}
    modifications.forEach{j[$0.key]=$0.value};return String(data:try! JSONSerialization.data(withJSONObject:j),encoding:.utf8)!
 }
 static func fresh(_ paired:Bool=false)->CourtlineSessionBroker {SecureStub.seen=[];SecureStub.bodies=[];SecureStub.pending=nil;SecureStub.hold=false;SecureStub.holdRecovery=false;SecureStub.wrongID=false;SecureStub.reject=false;SecureStub.wrongFamily=false;saves=0;let b=CourtlineSessionBroker();b.testSetup(paired);return b}
 static func main(){
    PinnedBackendRequest.testProtocols=[SecureStub.self]
    check(SecureBackendQR(qr()) != nil,"migration parses")
    check(SecureBackendQR(qr("enroll")) != nil,"enrollment parses")
    let invalid:[[String:Any]]=[["origin":"http://192.168.1.2:18100"],["origin":"https://example.com:18101"],["origin":"https://192.168.1.2:18101?key=bad"],["backendId":"bad"],["certificateSha256":"abc"],["enrollmentKey":"en_bad"],["purpose":"main"],["version":2]]
    for edits in invalid {check(SecureBackendQR(qr("migrate",edits))==nil,"unsafe QR rejected")}
    func der(_ tag:UInt8,_ bytes:[UInt8])->[UInt8]{[tag,UInt8(bytes.count)]+bytes}
    func dates(_ a:String,_ b:String,_ tag:UInt8=0x18)->Data {let validity=der(0x30,der(tag,Array(a.utf8))+der(tag,Array(b.utf8)));return Data(der(0x30,der(0x30,[0x02,1,1,0x30,0,0x30,0]+validity)))}
    check(BackendCertificateDates.valid(dates("20200101000000Z","20300101000000Z")),"current dates valid")
    check(!BackendCertificateDates.valid(dates("20000101000000Z","20010101000000Z")),"expired rejected")
    check(!BackendCertificateDates.valid(dates("20400101000000Z","20410101000000Z")),"future rejected")
    check(!BackendCertificateDates.valid(dates("20209901000000Z","20300101000000Z")),"invalid calendar rejected")
    check(BackendCertificateDates.valid(dates("500101000000Z","490101000000Z",0x17)),"UTC1950 to2049 pivot")
    check(!BackendCertificateDates.valid(dates("20200101000000Z","20300101000000Z").dropLast()),"truncated rejected")
    let certificates:[String:String]=[
        "current":"MIIDdzCCAl+gAwIBAgIJJbSFWe02O728MA0GCSqGSIb3DQEBCwUAMD8xPTA7BgNVBAMTNGNvdXJ0bGluZS0xMjM0NTY3OC0xMjM0LTEyMzQtMTIzNC0xMjM0NTY3ODlhYmMubG9jYWwwHhcNMjYxMTE1MTY0MzU5WhcNMjcxMTE1MTY0MzU5WjA/MT0wOwYDVQQDEzRjb3VydGxpbmUtMTIzNDU2NzgtMTIzNC0xMjM0LTEyMzQtMTIzNDU2Nzg5YWJjLmxvY2FsMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA5o5h0qI960U9cHffj0KVup0YDbLO8XgyMBcn+Fj++8KdrxKSai8u9cZYtK2zfGSSegIlnEr15RVmWCMUY85B805c0gdFI0+gAwQyW2BS8BVyI9/frSOEu1xoTCpPmiqEBheH6VAPOQw05/Y4OTS5W4Pv6B6Nf5JlAp5U6GE3jaWw6aZqT7wTTWqHnjwV1V8jcVMYUfEbSB0D5tUwilTi0whM3SlONTSlxBSECdXIVB3v/QT7rHaUWRw24R5JRQ+tV8/K7zRAwBgvxZKXdrNbUlp4NvsU4Cr09q0g8Ygvrjwfd5jzTeI7G1RYnTXwwn4c/x11+mlmtOLv9CbUdNtbswIDAQABo3YwdDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIFoDATBgNVHSUEDDAKBggrBgEFBQcDATA/BgNVHREEODA2gjRjb3VydGxpbmUtMTIzNDU2NzgtMTIzNC0xMjM0LTEyMzQtMTIzNDU2Nzg5YWJjLmxvY2FsMA0GCSqGSIb3DQEBCwUAA4IBAQDGoGWNz2hMPWns6RhoDN82m81h3MjXCnc4D0nUuLQQ4HnUnGD3lj20554u80eD/TaWpMJ2YWE9Vf+eYzNxYoVNgpgZSCM1ge9JkxcQoAShaWizuw41bo8kUzaQGs7loW6pwLKpyl9qJUTVKswRR7Hge0Qb6bJajFGMFaBrdSmobqPJ5nW5M280H6+YPxRcOXhOlTTqKz/XgYXQO7YibufgzBElkzuX2ybXRpT3TKpK33PamaCyx/Bze+uFEI6MIvVxkNZHZR83fUM5CsFH8Bk8l/Dt8j0+GL3Oc+JMOepOM0sSGJsgkvu1NYV55zQAtq43FjfOyiFTVvqEjbkKCoj3",
        "expired":"MIIDIjCCAgqgAwIBAgIUYqg2EBwaqNCQfI7tgnv3CTsSJLYwDQYJKoZIhvcNAQELBQAwHzEdMBsGA1UEAwwUY291cnRsaW5lLXRlc3QubG9jYWwwHhcNMDAwMTAxMDAwMDAwWhcNMDEwMTAxMDAwMDAwWjAfMR0wGwYDVQQDDBRjb3VydGxpbmUtdGVzdC5sb2NhbDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALLitm07bXwJexbnXZwqKoeyqMeq+Nt1UMS6bzCoW7tqO8A46e+kzLM9AQ46XL1a00jBfbINIcSSTLdJq5nOacIVEeSrpBbfluDTnYtKTo17RUIaKfClx6w+zN9tXK9xfmTFry+29GfK2xAKipBN+KIDCFrGfPM0Q3D0n0GgSqD6eVGEs+fsz+jY5Z7yPSG4KD/EZk7FsE7kuOhQbwo8MVn8NS97tVnxFcj8l3SFzlLC2jc+Q6/N3pp803YsCMA9otLYwGE0sHobGh1OHCOnoOYC4oKc38gYDoVNXOjFTDDov0hioIC4qjKpfwunCuXt6Ij8TyMwYPrLKz0q22kfqr8CAwEAAaNWMFQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCBaAwEwYDVR0lBAwwCgYIKwYBBQUHAwEwHwYDVR0RBBgwFoIUY291cnRsaW5lLXRlc3QubG9jYWwwDQYJKoZIhvcNAQELBQADggEBAFJaqMEtq4lKCcfL+NYFnZelTLjvlnsgzoh+r5Zx9xMBUkV8kJ+dygyHcygFb4c0Juc9G/IceHaOZ9WsKnUKMngT4GZIyDZZcFyXEqNAarRTFJeLA09afTzvY/h23T6WXLS6bAs+8tBhQJXyaNtcAB6K5fatWUmyPymWPccusi5gi1FDojZTED0p2m14FkDhP89csCwDWHDniqUffxpPlwyW4qaPPsylx2kgxu+RKx0hgw/gTGq3ihafOkPcDXfP1Y2q9eTIRWk6SVNVZi2bYSdZQFw9vcgPnAtR4RfiF2SWNMfjPgcRYSiEH0mszfOgsLB2Jl5d8xvpnIn8nO0pvWU=",
        "future":"MIIDIjCCAgqgAwIBAgIUYqg2EBwaqNCQfI7tgnv3CTsSJLYwDQYJKoZIhvcNAQELBQAwHzEdMBsGA1UEAwwUY291cnRsaW5lLXRlc3QubG9jYWwwHhcNNDAwMTAxMDAwMDAwWhcNNDEwMTAxMDAwMDAwWjAfMR0wGwYDVQQDDBRjb3VydGxpbmUtdGVzdC5sb2NhbDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALLitm07bXwJexbnXZwqKoeyqMeq+Nt1UMS6bzCoW7tqO8A46e+kzLM9AQ46XL1a00jBfbINIcSSTLdJq5nOacIVEeSrpBbfluDTnYtKTo17RUIaKfClx6w+zN9tXK9xfmTFry+29GfK2xAKipBN+KIDCFrGfPM0Q3D0n0GgSqD6eVGEs+fsz+jY5Z7yPSG4KD/EZk7FsE7kuOhQbwo8MVn8NS97tVnxFcj8l3SFzlLC2jc+Q6/N3pp803YsCMA9otLYwGE0sHobGh1OHCOnoOYC4oKc38gYDoVNXOjFTDDov0hioIC4qjKpfwunCuXt6Ij8TyMwYPrLKz0q22kfqr8CAwEAAaNWMFQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCBaAwEwYDVR0lBAwwCgYIKwYBBQUHAwEwHwYDVR0RBBgwFoIUY291cnRsaW5lLXRlc3QubG9jYWwwDQYJKoZIhvcNAQELBQADggEBAEHkAbOMTGTcWju8q1Auytd0ET6FN2sSVYR5V1bbg0mwGiFt2ZF1oBucdlCy78QLlqUXTdGlyg7MnFlQ/QrNl8EMYVNtFmkd30igaj1gUhEpplWRLOO7OEusH4SZDvJOO1UtxdLMEKUkzP1/ijy5rDg7IDt+4mzUb0fvE1xQAGQDg/wiwI2hYx1aC/v7Bizzajt3/OdXEgKdcoVuOlcMj2IeCFDdqzPZil+0i785UBU/v8ZQ7n1pThs5645Sh/eHqwJ8H8kOuUZXWrrlxpT2oBIWSMwBZTsqh9g2DCDvQz4G03Iufd7/xS1wSW1ef4iiJz1EEGHYThkjPBh7xxi1OAo="
    ]
    for name in ["current","expired","future"] {
        let der=Data(base64Encoded:certificates[name]!)!,cert=SecCertificateCreateWithData(nil,der as CFData)!
        var trust:SecTrust?;check(SecTrustCreateWithCertificates(cert,SecPolicyCreateSSL(true,nil),&trust)==errSecSuccess,"test trust created")
        let pin=SHA256.hash(data:der).map{String(format:"%02x",$0)}.joined()
        let verified=PinnedBackendRequest.validate(serverTrust:trust!,cert:cert,pin:pin)
        if name=="current" && !verified { var e:CFError?;let evaluated=SecTrustEvaluateWithError(trust!,&e);FileHandle.standardError.write(Data(("CERT DIAG dates=\(BackendCertificateDates.valid(der)) evaluated=\(evaluated) error=\(String(describing:e))\n").utf8)) }
        check(verified==(name=="current"),"actual Security trust validation "+name)
        check(!PinnedBackendRequest.validate(serverTrust:trust!,cert:cert,pin:String(repeating:"0",count:64)),"wrong pin rejected "+name)
    }
    check(!BackendCertificateDates.valid(Data()),"empty certificate rejected")
    check(!BackendCertificateDates.valid(Data([0x30,0x80,0,0])),"indefinite DER rejected")
    do {let b=fresh(true);var finished=false;var error:Error?;b.enroll(qr()){error=$0;finished=true};wait{finished};check(error==nil && b.pairedSecure && b.ready && b.role=="viewer" && saves==1,"migration commits once")
        check(SecureStub.seen.count==2,"identity then reopen only");check(SecureStub.seen[0].value(forHTTPHeaderField:"X-Courtline-Key")==nil,"identity no secret");check(SecureStub.seen[1].value(forHTTPHeaderField:"X-Courtline-Key")?.hasPrefix("ds_")==true,"registered key only after identity")
        SecureStub.seen=[];var reopened=false;b.coldStart{check($0==nil,"cold restart succeeds");reopened=true};wait{reopened};check(SecureStub.seen.count==2 && SecureStub.seen[0].url?.path=="/api/server-identity" && SecureStub.seen[1].url?.path=="/api/device-session","saved address checked before reopening; no discovery needed")
        var bad=false;b.enroll("http://192.168.1.2:18100/api/stats?key=en_"+String(repeating:"c",count:64)){bad=$0 != nil};check(bad && SecureStub.seen.count==2,"no HTTP fallback")
    }
    do {let b=fresh(true);SecureStub.wrongID=true;var finished=false;b.enroll(qr()){check($0 != nil,"wrong identity error");finished=true};wait{finished};check(saves==0 && SecureStub.seen.count==1 && !b.pairedSecure,"wrong ID never receives credential")}
    for resume in [false,true] {let b=fresh(true);SecureStub.hold=true;var finished=false;b.enroll(qr()){check($0 != nil,"cancel error");finished=true};wait{SecureStub.pending != nil};b.setForeground(false);if resume{b.setForeground(true)};wait{finished};check(saves==0 && SecureStub.seen.count==1 && !b.pairedSecure,"background generation cannot commit")}
    do {let b=fresh(true);b.setForeground(false);var failed=false;b.enroll(qr()){failed=$0 != nil};check(failed && SecureStub.seen.isEmpty,"background admission zero HTTP")}
    do {let b=fresh();var failed=false;b.enroll(qr()){failed=$0 != nil};check(failed && SecureStub.seen.isEmpty,"unpaired migration denied")}
    do {let b=fresh(true);var failed=false;b.enroll(qr("enroll")){failed=$0 != nil};check(failed && SecureStub.seen.isEmpty,"registered enrollment no duplicates")}
    do {let b=fresh();var finished=false;b.enroll(qr("enroll")){check($0==nil,"new enroll succeeds");finished=true};wait{finished};check(b.pairedSecure && b.role=="viewer" && saves==1,"new enrolled Companion");check(SecureStub.seen[1].value(forHTTPHeaderField:"X-Courtline-Key")?.hasPrefix("en_")==true,"enrollment credential scoped")}
    let renewed=qr("migrate",["certificateSha256":String(repeating:"b",count:64)])
    do {let b=fresh(true);b.testTrusted();var denied=false;b.enroll(renewed){denied=$0 != nil};check(denied && SecureStub.seen.isEmpty && b.savedPin==String(repeating:"a",count:64),"renewal requires explicit confirmation")
        let confirmation=b.certificateReplacement(renewed);check(confirmation != nil,"same ID renewal prompts")
        var finished=false;b.enroll(renewed,confirmedReplacement:confirmation){check($0==nil,"confirmed renewal succeeds");finished=true};wait{finished};check(saves==1 && b.savedPin==String(repeating:"b",count:64) && SecureStub.seen.count==2,"renewal retains family and commits pin after verification")
    }
    do {let b=fresh(true);b.testTrusted();let other=qr("migrate",["backendId":SecureStub.family,"certificateSha256":String(repeating:"b",count:64)]);check(b.certificateReplacement(other)==nil,"different Backend cannot use renewal");var denied=false;b.enroll(other){denied=$0 != nil};check(denied && SecureStub.seen.isEmpty,"different Backend no credential")}
    do {let b=fresh(true);b.testTrusted();let confirmation=b.certificateReplacement(renewed);b.setForeground(false);b.setForeground(true);var denied=false;b.enroll(renewed,confirmedReplacement:confirmation){denied=$0 != nil};check(denied && SecureStub.seen.isEmpty && saves==0,"background invalidates renewal confirmation")}
    do {let b=fresh(true);b.testTrusted();let confirmation=b.certificateReplacement(renewed);let altered=qr("migrate",["certificateSha256":String(repeating:"c",count:64)]);var denied=false;b.enroll(altered,confirmedReplacement:confirmation){denied=$0 != nil};check(denied && SecureStub.seen.isEmpty,"confirmation bound to exact QR")}
    do {let b=fresh(true);b.testTrusted();let confirmation=b.certificateReplacement(renewed);SecureStub.wrongID=true;var finished=false;b.enroll(renewed,confirmedReplacement:confirmation){check($0 != nil,"renewed endpoint wrong ID rejected");finished=true};wait{finished};check(saves==0 && SecureStub.seen.count==1 && b.savedPin==String(repeating:"a",count:64),"wrong renewed ID receives no credential")}
    do {let b=fresh(true);b.testTrusted();let confirmation=b.certificateReplacement(renewed);SecureStub.wrongFamily=true;var finished=false;b.enroll(renewed,confirmedReplacement:confirmation){check($0 != nil,"different family rejected");finished=true};wait{finished};check(saves==0 && b.savedPin==String(repeating:"a",count:64),"different family cannot commit new trust")}
    check(SecureBackendQR(qr("recover")) != nil,"recovery QR parses")
    for edits:[String:Any] in [["sessionId":"bad"],["recoveryKey":"rc_short"],["enrollmentKey":"en_"+String(repeating:"a",count:64)]] {check(SecureBackendQR(qr("recover",edits))==nil,"malformed recovery rejected")}
    do {let b=fresh();var denied=false;b.enroll(qr("recover")){denied=$0 != nil};check(denied && SecureStub.seen.isEmpty,"recovery requires explicit confirmation")}
    for paired in [false,true] {let b=fresh(paired);let text=qr("recover");let confirmation=b.recoveryConfirmation(text);check(confirmation != nil,"recovery confirmation available")
        var done=false;b.enroll(text,confirmedRecovery:confirmation){check($0==nil,"recovery succeeds");done=true};wait{done}
        check(saves==1 && b.ready && b.role=="viewer" && !b.unlocked,"recovery commits Companion only")
        check(SecureStub.seen.count==2 && SecureStub.seen[0].value(forHTTPHeaderField:"X-Courtline-Key")==nil,"recovery identity first without key")
        check(SecureStub.seen[1].value(forHTTPHeaderField:"X-Courtline-Key")?.hasPrefix("rc_")==true,"recovery uses only scoped ticket")
        let body=try! JSONSerialization.jsonObject(with:SecureStub.bodies[1]) as! [String:Any]
        check(body["action"] as? String=="recover" && body["name"]==nil,"recovery action does not rename or reenroll")
    }
    do {let b=fresh();let text=qr("recover"),confirmation=b.recoveryConfirmation(qr("recover"));b.setForeground(false);b.setForeground(true);var denied=false;b.enroll(text,confirmedRecovery:confirmation){denied=$0 != nil};check(denied && SecureStub.seen.isEmpty,"recovery confirmation invalidated by background")}
    do {let b=fresh();let confirmation=b.recoveryConfirmation(qr("recover"));var denied=false;b.enroll(qr("recover",["sessionId":SecureStub.id]),confirmedRecovery:confirmation){denied=$0 != nil};check(denied && SecureStub.seen.isEmpty,"confirmation bound to target QR")}
    for wrongIdentity in [false,true] {let b=fresh(true);let text=qr("recover");SecureStub.wrongID=wrongIdentity;SecureStub.wrongFamily = !wrongIdentity;var done=false;b.enroll(text,confirmedRecovery:b.recoveryConfirmation(text)){check($0 != nil,"recovery mismatch rejected");done=true};wait{done};check(saves==0 && SecureStub.seen.count==(wrongIdentity ? 1:2),"recovery mismatch never commits")}
    do {let b=fresh();let text=qr("recover");SecureStub.reject=true;var done=false;b.enroll(text,confirmedRecovery:b.recoveryConfirmation(text)){check($0 != nil,"recovery denied");done=true};wait{done};check(saves==0,"rejected recovery not saved")}
    do {let b=fresh(true);b.testStorageFailure();let text=qr("recover");var done=false;b.enroll(text,confirmedRecovery:b.recoveryConfirmation(text)){check($0?.localizedDescription.contains("could not be saved")==true,"storage failure explains recovery uncertainty");done=true};wait{done};check(saves==0 && !b.pairedSecure,"storage failure leaves old pairing")}
    for resume in [false,true] {let b=fresh(true);let text=qr("recover");SecureStub.holdRecovery=true;var done=false;b.enroll(text,confirmedRecovery:b.recoveryConfirmation(text)){check($0?.localizedDescription.contains("may have completed")==true,"post-dispatch interruption explains uncertainty");done=true};wait{SecureStub.pending != nil};check(SecureStub.seen.count==2,"recovery POST dispatched");b.setForeground(false);if resume{b.setForeground(true)};wait{done};check(saves==0 && !b.pairedSecure,"post-dispatch cancellation cannot commit")}
    print("PASS \(checks) secure QR and broker fake-network checks; real TLS/mDNS/device testing still required")
 }
}
