private final class TestProtocol:URLProtocol {
 static var seen:[URLRequest]=[]
 static var bad=false
 override class func canInit(with request:URLRequest)->Bool{true}
 override class func canonicalRequest(for request:URLRequest)->URLRequest{request}
 override func startLoading(){Self.seen.append(request);client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:200,httpVersion:nil,headerFields:nil)!,cacheStoragePolicy:.notAllowed);client?.urlProtocol(self,didLoad:Data((Self.bad ? "bad":"{\"version\":1,\"backendId\":\"11111111-1111-4111-8111-111111111111\"}").utf8));client?.urlProtocolDidFinishLoading(self)}
 override func stopLoading(){}
}
@main struct PinnedRuntime {
 static var checks=0
 static func check(_ value:Bool,_ message:String){precondition(value,message);checks += 1}
 static func main(){
 let id="11111111-1111-4111-8111-111111111111"
 let j:[String:Any]=["type":"courtline-secure","version":1,"origin":"https://192.168.1.2:18200","backendId":id,"certificateSha256":String(repeating:"a",count:64),"enrollmentKey":"en_SECRET","recoveryKey":"rc_SECRET"]
 let text=String(data:try! JSONSerialization.data(withJSONObject:j),encoding:.utf8)!
 let qr=SecureBackendQR(text)!;check(Mirror(reflecting:qr).children.count==2,"only public trust/origin retained")
 PinnedBackendRequest.testProtocols=[TestProtocol.self]
 for bad in [false,true]{TestProtocol.bad=bad;TestProtocol.seen=[];let r=PinnedBackendRequest(trust:qr.trust,origin:qr.origin);var done=false,notes=[String]();r.observation={notes.append($0)}
 r.start(timeout:1){status,json,error in check((error != nil)==bad,"valid JSON required");check(status==200,"status retained even malformed JSON");if !bad{check(json["backendId"] as? String==id,"identity returned")};done=true}
 let end=Date().addingTimeInterval(4);while !done && Date()<end{RunLoop.main.run(until:Date().addingTimeInterval(0.01))};check(done,"bounded completion")
 let request=TestProtocol.seen[0];check(request.url?.path=="/api/server-identity" && request.httpBody==nil && request.httpMethod=="GET","read-only identity")
 check(request.value(forHTTPHeaderField:"X-Courtline-Key")==nil && request.value(forHTTPHeaderField:"Cookie")==nil,"no key or cookie")
 check(notes.contains("HTTP status: 200"),"HTTP stage visible")
 check(!notes.joined().contains("SECRET") && !notes.joined().contains("192.168"),"no secret or address diagnostics")
 }
 print("PASS \(checks) credential-free diagnostic fake-network checks; actual TLS/iPad testing remains")
 }
}
