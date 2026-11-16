// CI only. All URLSession requests intercepted; never uses real LAN.
private final class HealthStub:URLProtocol {
 static var status=401;static var errorCode:Int?;static var pending=false;static var seen:[URLRequest]=[]
 override class func canInit(with request:URLRequest)->Bool {true}
 override class func canonicalRequest(for request:URLRequest)->URLRequest {request}
 override func startLoading() {
  Self.seen.append(request)
  if Self.pending{return}
  if let code=Self.errorCode {client?.urlProtocol(self,didFailWithError:NSError(domain:NSURLErrorDomain,code:code,userInfo:[NSLocalizedDescriptionKey:"secret-token-url"]));return}
  let response=HTTPURLResponse(url:request.url!,statusCode:Self.status,httpVersion:nil,headerFields:["Set-Cookie":"secret"] )!
  client?.urlProtocol(self,didReceive:response,cacheStoragePolicy:.notAllowed)
  client?.urlProtocolDidFinishLoading(self)
 }
 override func stopLoading() {}
}
extension ConnectionDiagnostics {
 fileprivate func testFireOuterDeadline(){precondition(deadline != nil);deadline?.perform()}
 fileprivate func testSetup(){configuration={let c=URLSessionConfiguration.ephemeral;c.protocolClasses=[HealthStub.self];return c}}
 fileprivate func testReentrantHeader()->String {
   var result="";completion={result=$0}
   let c=URLSessionConfiguration.ephemeral;c.protocolClasses=[HealthStub.self]
   let session=URLSession(configuration:c),task=session.dataTask(with:URL(string:"http://10.0.0.2:3999/api/session")!)
   let response=HTTPURLResponse(url:task.originalRequest!.url!,statusCode:401,httpVersion:nil,headerFields:nil)!
   self.urlSession(session,dataTask:task,didReceive:response){disposition in
     precondition(disposition == .cancel)
     self.urlSession(session,task:task,didCompleteWithError:NSError(domain:NSURLErrorDomain,code:NSURLErrorCancelled))
   }
   session.invalidateAndCancel();return result
 }
 fileprivate func testRedirect()->String {
   var result="";completion={result=$0}
   let c=URLSessionConfiguration.ephemeral;c.protocolClasses=[HealthStub.self]
   let session=URLSession(configuration:c),task=session.dataTask(with:URL(string:"http://10.0.0.2:3999/api/session")!)
   let response=HTTPURLResponse(url:task.originalRequest!.url!,statusCode:302,httpVersion:nil,headerFields:nil)!
   self.urlSession(session,task:task,willPerformHTTPRedirection:response,newRequest:URLRequest(url:URL(string:"https://example.com")!)){precondition($0==nil)}
   session.invalidateAndCancel();return result
 }
}
extension NetworkTestModel {
 fileprivate func testConfigure(_ observe:@escaping(URL,@escaping(String)->Void)->()->Void) {
  self.observe=observe
  makeProbe={let p=ConnectionDiagnostics();p.testSetup();return p}
 }
}
@main struct HealthRuntime {
 static func run(_ label:String,status:Int=401,error:Int?=nil,pending:Bool=false,forceDeadline:Bool=false) {
  HealthStub.status=status;HealthStub.errorCode=error;HealthStub.pending=pending;HealthStub.seen=[]
  let p=ConnectionDiagnostics();p.testSetup();var result:String?;var completions=0;var fired=false
  let started=ProcessInfo.processInfo.systemUptime
  p.start(origin:URL(string:"http://10.0.0.2:3999")!){completions += 1;result=$0}
  let deadline=Date().addingTimeInterval(23)
  while result==nil && Date()<deadline {
   RunLoop.main.run(until:Date().addingTimeInterval(0.01))
   if forceDeadline && !fired && !HealthStub.seen.isEmpty {fired=true;p.testFireOuterDeadline()}
  }
  precondition(result != nil && completions==1)
  precondition(ProcessInfo.processInfo.systemUptime-started < 22.5)
  precondition(HealthStub.seen.count==1)
  let req=HealthStub.seen[0];precondition(req.httpMethod=="GET" && req.url!.path=="/api/session" && URLComponents(url:req.url!,resolvingAgainstBaseURL:false)!.query==nil)
  precondition(req.httpBody==nil && req.value(forHTTPHeaderField:"X-Courtline-Key")==nil && req.value(forHTTPHeaderField:"Cookie")==nil && req.value(forHTTPHeaderField:"Authorization")==nil)
  FileHandle.standardError.write(Data(("HEALTH RESULT "+label+": "+result!+"\n").utf8))
  precondition(!result!.contains("secret"))
  if forceDeadline {precondition(fired && result!.contains("Deadline reached"))}
  else if pending {precondition(result!.contains("NSURLErrorDomain -1001") || result!.contains("Deadline reached"))}
  else if let code=error {precondition(result!.contains("NSURLErrorDomain "+String(code)))}
  else {precondition(result!.contains("HTTP "+String(status)))}
  print("PASS "+label)
 }
 static func testModel(){
  HealthStub.seen=[];HealthStub.pending=false;HealthStub.errorCode=nil;HealthStub.status=401
  let m=NetworkTestModel();var probes=0
  m.testConfigure{url,done in precondition(url.absoluteString=="http://10.0.0.2:3999");probes += 1;done("localNetworkDenied");return {}}
  precondition(HealthStub.seen.isEmpty && !m.busy && probes==0);print("PASS model launch makes zero requests")
  m.test("http://10.0.0.2?key=secret");precondition(HealthStub.seen.isEmpty && !m.busy);print("PASS invalid input never requests")
  m.test("http://10.0.0.2:3999");m.test("http://10.0.0.3:3999")
  var end=Date().addingTimeInterval(23);while m.busy && Date()<end {RunLoop.main.run(until:Date().addingTimeInterval(0.01))}
  precondition(!m.busy && HealthStub.seen.count==1 && m.result.contains("HTTP 401") && probes==0);print("PASS explicit HTTP test single flight no TCP")
  HealthStub.errorCode = -1009;HealthStub.seen=[]
  m.test("http://10.0.0.2:3999")
  end=Date().addingTimeInterval(23);while m.busy && Date()<end {RunLoop.main.run(until:Date().addingTimeInterval(0.01))}
  precondition(!m.busy && HealthStub.seen.count==1 && probes==1 && m.result.contains("localNetworkDenied"));print("PASS offline test same-origin fake TCP only")
  m.testConfigure{_,done in done("secret-url-token");return {}};HealthStub.seen=[]
  m.test("http://10.0.0.2:3999")
  end=Date().addingTimeInterval(23);while m.busy && Date()<end {RunLoop.main.run(until:Date().addingTimeInterval(0.01))}
  precondition(!m.busy && !m.result.contains("secret") && m.result.contains("unavailable"));print("PASS path observation allowlist")
  HealthStub.seen=[];HealthStub.pending=true;m.test("http://10.0.0.2:3999");m.setActive(false)
  RunLoop.main.run(until:Date().addingTimeInterval(0.05))
  precondition(!m.busy && m.result.contains("cancelled") && probes==1);print("PASS leaving view invalidates pending HTTP and no followup TCP")
  let count=HealthStub.seen.count;m.test("http://10.0.0.2:3999");precondition(HealthStub.seen.count==count && !m.busy);print("PASS inactive test cannot start request")
  HealthStub.pending=false;HealthStub.errorCode = -1009;HealthStub.seen=[]
  var late:((String)->Void)?;var cancelled=0
  m.testConfigure{_,done in late=done;return {cancelled += 1}}
  m.setActive(true);precondition(HealthStub.seen.isEmpty);print("PASS returning foreground never retries")
  m.test("http://10.0.0.2:3999");end=Date().addingTimeInterval(23)
  while late==nil && Date()<end {RunLoop.main.run(until:Date().addingTimeInterval(0.01))}
  precondition(late != nil && m.busy);m.setActive(false)
  precondition(cancelled==1 && !m.busy);print("PASS background cancels active path probe")
  let stopped=m.result;late?("ready");precondition(m.result==stopped && !m.busy);print("PASS stale path completion ignored")
 }
 static func main(){
  for code in [200,401,403,404,503]{run("HTTP "+String(code),status:code)}
  for code in [-1009,-1004,-1001,-1022]{run("transport "+String(code),error:code)}
  for bad in ["https://example.com","http://127.0.0.1:8","http://user:pass@10.0.0.2","http://10.0.0.2/path","http://10.0.0.2?key=secret","http://10.0.0.2#secret"]{precondition(ConnectionDiagnostics.origin(bad)==nil)}
  print("PASS six unsafe origins rejected")
  let h=ConnectionDiagnostics();precondition(h.testReentrantHeader().contains("HTTP 401"));print("PASS reentrant cancel preserves HTTPstatus")
  let d=ConnectionDiagnostics();precondition(d.testRedirect().contains("redirect refused"));print("PASS redirect refused")
  run("bounded timeout completion",pending:true)
  run("deterministic outer deadline",pending:true,forceDeadline:true)
  testModel()
  let identity=ConnectionDiagnostics.identity();precondition(identity.contains("Effective ATS:"));precondition(identity.contains("Bundle:") && identity.contains("Executable UUID:") && identity.contains("Local Network description:"));print("PASS bounded identity fields")
 }
}
