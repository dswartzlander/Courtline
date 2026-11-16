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
 }
 override func stopLoading() {}
}
extension ConnectionDiagnostics {
 fileprivate func testSetup(){configuration={let c=URLSessionConfiguration.ephemeral;c.protocolClasses=[HealthStub.self];return c}}
 fileprivate func testRedirect()->String {
   var result="";completion={result=$0}
   let c=URLSessionConfiguration.ephemeral;c.protocolClasses=[HealthStub.self]
   let session=URLSession(configuration:c),task=session.dataTask(with:URL(string:"http://10.0.0.2:3999/api/health")!)
   let response=HTTPURLResponse(url:task.originalRequest!.url!,statusCode:302,httpVersion:nil,headerFields:nil)!
   self.urlSession(session,task:task,willPerformHTTPRedirection:response,newRequest:URLRequest(url:URL(string:"https://example.com")!)){precondition($0==nil)}
   session.invalidateAndCancel();return result
 }
}
@main struct HealthRuntime {
 static func run(_ label:String,status:Int=401,error:Int?=nil,pending:Bool=false) {
  HealthStub.status=status;HealthStub.errorCode=error;HealthStub.pending=pending;HealthStub.seen=[]
  let p=ConnectionDiagnostics();p.testSetup();var result:String?
  p.start(origin:URL(string:"http://10.0.0.2:3999")!){result=$0}
  let deadline=Date().addingTimeInterval(12)
  while result==nil && Date()<deadline {RunLoop.main.run(until:Date().addingTimeInterval(0.01))}
  precondition(result != nil)
  precondition(HealthStub.seen.count==1)
  let req=HealthStub.seen[0];precondition(req.httpMethod=="GET" && req.url!.path=="/api/health" && URLComponents(url:req.url!,resolvingAgainstBaseURL:false)!.query==nil)
  precondition(req.httpBody==nil && req.value(forHTTPHeaderField:"X-Courtline-Key")==nil && req.value(forHTTPHeaderField:"Cookie")==nil && req.value(forHTTPHeaderField:"Authorization")==nil)
  FileHandle.standardError.write(Data(("HEALTH RESULT "+label+": "+result!+"\n").utf8))
  precondition(!result!.contains("secret"))
  if pending {precondition(result!.hasPrefix("Deadline reached"))}
  else if let code=error {precondition(result!.contains("NSURLErrorDomain "+String(code)))}
  else {precondition(result!.hasPrefix("HTTP "+String(status)))}
  print("PASS "+label)
 }
 static func main(){
  for code in [200,401,403,404,503]{run("HTTP "+String(code),status:code)}
  for code in [-1009,-1004,-1001,-1022]{run("transport "+String(code),error:code)}
  for bad in ["https://example.com","http://127.0.0.1:8","http://user:pass@10.0.0.2","http://10.0.0.2/path","http://10.0.0.2?key=secret","http://10.0.0.2#secret"]{precondition(ConnectionDiagnostics.origin(bad)==nil)}
  print("PASS six unsafe origins rejected")
  let d=ConnectionDiagnostics();precondition(d.testRedirect().contains("redirect refused"));print("PASS redirect refused")
  run("bounded deadline",pending:true)
  let identity=ConnectionDiagnostics.identity();precondition(identity.contains("Bundle:") && identity.contains("Executable UUID:") && identity.contains("Local Network description:"));print("PASS bounded identity fields")
 }
}
