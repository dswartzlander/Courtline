// CI only: concatenated with exact broker. All HTTP/probes are synthetic; no successful Keychain writes.
#if BASELINE
extension CourtlineSessionBroker {
 // Baseline controller never informed broker of inactivity. This no-op models that exact absence.
 func setEnrollmentActive(_ active:Bool) {}
}
#endif
private final class LifecycleStub:URLProtocol {
 static var pending:LifecycleStub?;static var seen=0;static var probes=0;static var pathDone:((String)->Void)?
 override class func canInit(with request:URLRequest)->Bool{true}
 override class func canonicalRequest(for request:URLRequest)->URLRequest{request}
 override func startLoading(){Self.seen += 1;Self.pending=self}
 override func stopLoading(){}
 static func error(_ code:Int){let p=pending!;pending=nil;p.client?.urlProtocol(p,didFailWithError:NSError(domain:NSURLErrorDomain,code:code))}
 static func revoked(){let p=pending!;pending=nil;p.client?.urlProtocol(p,didReceive:HTTPURLResponse(url:p.request.url!,statusCode:403,httpVersion:nil,headerFields:nil)!,cacheStoragePolicy:.notAllowed);p.client?.urlProtocol(p,didLoad:Data("{\"code\":\"device_revoked\"}".utf8));p.client?.urlProtocolDidFinishLoading(p)}
 static func success(){let p=pending!;pending=nil;let id="11111111-1111-4111-8111-111111111111";let data=try! JSONSerialization.data(withJSONObject:["viewerKey":"ds_"+String(repeating:"b",count:64),"deviceId":"session_"+id,"sessionId":id,"role":"viewer","perDeviceControlPINs":true]);p.client?.urlProtocol(p,didReceive:HTTPURLResponse(url:p.request.url!,statusCode:200,httpVersion:nil,headerFields:nil)!,cacheStoragePolicy:.notAllowed);p.client?.urlProtocol(p,didLoad:data);p.client?.urlProtocolDidFinishLoading(p)}
}
extension CourtlineSessionBroker {
 fileprivate func setupLifecycleTest(){
  origin=nil;viewerKey="";mainKey="";ready=false;revoked=false
  let c=URLSessionConfiguration.ephemeral;c.protocolClasses=[LifecycleStub.self]
  network=URLSession(configuration:c,delegate:self,delegateQueue:nil)
  pathProbe={host,done in precondition(host.absoluteString=="http://10.0.0.2:3999");LifecycleStub.probes += 1;LifecycleStub.pathDone=done}
 }
 fileprivate func seedPairing(){origin=URL(string:"http://10.0.0.2:3999")!;viewerKey="ds_"+String(repeating:"b",count:64);ready=true}
 fileprivate func seedControl(){role="main";mainKey="test-main";grant="test-grant";sessionBound=true}
 fileprivate var controlRetained:Bool{role=="main" && mainKey=="test-main" && grant=="test-grant" && sessionBound}
}
@main struct LifecycleRuntime {
 static let ticket="http://10.0.0.2:3999/api/stats?key=en_"+String(repeating:"a",count:64)
 static func wait(_ condition:()->Bool){let until=Date().addingTimeInterval(5);while !condition() && Date()<until{RunLoop.main.run(until:Date().addingTimeInterval(0.01))};precondition(condition())}
 static func fresh()->CourtlineSessionBroker{LifecycleStub.pending=nil;LifecycleStub.seen=0;LifecycleStub.probes=0;LifecycleStub.pathDone=nil;let b=CourtlineSessionBroker();b.setupLifecycleTest();return b}
 static func main(){
  do {let b=fresh();b.setEnrollmentActive(false);var e:String?;b.enroll(ticket){e=$0?.localizedDescription ?? "success"};RunLoop.main.run(until:Date().addingTimeInterval(0.05))
   if LifecycleStub.seen != 0 || e != "PAIR_CHANGED" {FileHandle.standardError.write(Data("RED: inactive admission starts enrollment HTTP\n".utf8));exit(1)}
   print("PASS inactive admission zero HTTP")}
  do {let b=fresh();var e:String?;b.enroll(ticket){e=$0?.localizedDescription};wait{LifecycleStub.pending != nil};LifecycleStub.error(-1004);wait{e != nil};precondition(e=="PAIR_CONNECT" && LifecycleStub.seen==1 && LifecycleStub.probes==0);print("PASS active transport flow unchanged")}
  for resume in [false,true] {let b=fresh();var e:String?;b.enroll(ticket){e=$0?.localizedDescription};wait{LifecycleStub.pending != nil};b.setEnrollmentActive(false);if resume{b.setEnrollmentActive(true)};LifecycleStub.error(-1009);wait{e != nil};precondition(e=="PAIR_CHANGED" && LifecycleStub.probes==0 && !b.ready);print("PASS inactive HTTP completion no TCP resume="+String(resume))}
  do {let b=fresh();var e:String?;b.enroll(ticket){e=$0?.localizedDescription};wait{LifecycleStub.pending != nil};b.setEnrollmentActive(false);b.setEnrollmentActive(true);LifecycleStub.success();wait{e != nil};precondition(e=="PAIR_CHANGED" && !b.ready && b.helperURL.isEmpty);print("PASS late successful response not persisted")}
  do {let b=fresh();var e:String?;b.enroll(ticket){e=$0?.localizedDescription};wait{LifecycleStub.pending != nil};LifecycleStub.error(-1009);wait{LifecycleStub.pathDone != nil};b.setEnrollmentActive(false);b.setEnrollmentActive(true);LifecycleStub.pathDone?("ready");wait{e != nil};precondition(e=="PAIR_CHANGED" && LifecycleStub.seen==1 && !b.ready);print("PASS stale path result dropped no replay")}
  do {let b=fresh();b.seedPairing();var e:String?;b.enroll(ticket){e=$0?.localizedDescription};wait{LifecycleStub.pending != nil};b.setEnrollmentActive(false);b.setEnrollmentActive(true);LifecycleStub.revoked();wait{e != nil};RunLoop.main.run(until:Date().addingTimeInterval(0.05));precondition(e=="PAIR_CHANGED" && LifecycleStub.seen==1 && b.revoked && !b.ready);print("PASS inactive same-family refresh cannot reenroll") }
  do {let b=fresh();b.seedControl();b.setEnrollmentActive(false);b.setEnrollmentActive(true);precondition(b.controlRetained && LifecycleStub.seen==0);print("PASS ordinary background retains existing Control grant")}
  do {let b=fresh();b.setEnrollmentActive(false);b.setEnrollmentActive(true);var e:String?;b.enroll(ticket){e=$0?.localizedDescription};wait{LifecycleStub.pending != nil};LifecycleStub.error(-1004);wait{e != nil};precondition(e=="PAIR_CONNECT" && LifecycleStub.seen==1);print("PASS camera permission return permits new explicit scan")}
 }
}
