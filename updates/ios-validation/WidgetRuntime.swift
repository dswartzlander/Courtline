// CI-only harness concatenated AFTER the exact shipping broker. Not included in the app.
private final class WidgetStub: URLProtocol {
    static let lock = NSLock()
    static var seen: [URLRequest] = []
    static var handler: ((URLRequest) -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock();Self.seen.append(request);let handler=Self.handler;Self.lock.unlock()
        guard let handler=handler,let url=request.url else {fatalError("No fake transport: real network forbidden")}
        let (status,data)=handler(request)
        let response=HTTPURLResponse(url:url,statusCode:status,httpVersion:"HTTP/1.1",headerFields:["Content-Type":"application/json"])!
        client?.urlProtocol(self,didReceive:response,cacheStoragePolicy:.notAllowed)
        client?.urlProtocol(self,didLoad:data);client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
    static func requests()->[URLRequest] {lock.lock();defer{lock.unlock()};return seen}
}
extension CourtlineSessionBroker {
    fileprivate func widgetTestSetup(main:Bool=true,locked:Bool=false) {
        origin=URL(string:"http://10.0.0.2:3999")!;viewerKey="test-viewer";mainKey=main ? "test-main" : "";role=main ? "main":"viewer"
        ready=true;revoked=false;controlAllowed=true;pinAvailable=true;grant=locked ? "":"test-grant";revision="test-revision";sessionBound=true
        let configuration=URLSessionConfiguration.ephemeral;configuration.protocolClasses=[WidgetStub.self]
        network=URLSession(configuration:configuration,delegate:self,delegateQueue:nil)
    }
    fileprivate func widgetTestInvalidate(){clearControl()}
}
@main struct WidgetRuntime {
    static let widget="https://app.scoreholio.com/overlay?account=test&game=game&court=1"
    static let host="http://10.0.0.3:8088"
    static func data(_ value:Any)->Data {try! JSONSerialization.data(withJSONObject:value)}
    static func defaultResponse(_ request:URLRequest)->(Int,Data) {
        let url=request.url!
        if url.host=="10.0.0.2",url.path=="/api/control-settings" {return (200,data(["lock":["enabled":true,"revision":"test-revision"],"sections":["vmix":["value":["address":host]]]]))}
        if url.host=="10.0.0.2",url.path=="/api/live" {return (200,data(["courts":Array(repeating:["stale":false,"error":""] as [String:Any],count:4),"snapshot":["vmixAddress":host,"courts":Array(repeating:["kind":"assigned","widgetUrl":widget],count:4)]]))}
        if url.host=="10.0.0.3",url.path=="/api/" {return (200,Data("OK".utf8))}
        fatalError("Unexpected fake request")
    }
    static func run(_ label:String,main:Bool=true,locked:Bool=false,input:String="Input & Name",address:String=host,url:String=widget,pre:(CourtlineSessionBroker)->Void={_ in},canSend:@escaping()->Bool={true},response:((URLRequest)->(Int,Data))?=nil,expectSend:Bool,expectStatus:Int?=nil) {
        WidgetStub.lock.lock();WidgetStub.seen=[];WidgetStub.handler=response ?? defaultResponse;WidgetStub.lock.unlock()
        let broker=CourtlineSessionBroker();broker.widgetTestSetup(main:main,locked:locked);let stamp=broker.stamp;pre(broker)
        var complete=false;var result:[String:Any]?
        broker.sendWidget(slot:0,input:input,widget:url,candidate:address,stamp:stamp,canSend:canSend){value,_ in result=value;complete=true}
        let until=Date().addingTimeInterval(0.7)
        while !complete && Date()<until {_ = RunLoop.main.run(mode:.default,before:Date().addingTimeInterval(0.01))}
        let sends=WidgetStub.requests().filter{$0.url?.host=="10.0.0.3"}
        precondition(sends.count==(expectSend ? 1:0),label+" wrong mutation count")
        if let status=expectStatus {precondition(result?["status"] as? Int==status,label+" wrong status")}
        for request in sends {
            precondition(request.httpMethod=="GET" && request.value(forHTTPHeaderField:"X-Courtline-Key")==nil,label+" credential leak")
            let q=URLComponents(url:request.url!,resolvingAgainstBaseURL:false)!.queryItems!
            precondition(q.count==3 && q.first{$0.name=="Function"}?.value=="BrowserNavigate",label+" function widening")
            precondition(q.first{$0.name=="Input"}?.value==input.trimmingCharacters(in:.whitespacesAndNewlines),label+" input mutation")
            precondition(q.first{$0.name=="Value"}?.value==url,label+" URL mutation")
        }
        print("PASS "+label)
    }
    static func main() {
        run("fixed encoded command",expectSend:true,expectStatus:200)
        run("Viewer denied even if draw lease exists",main:false,expectSend:false)
        run("locked Main denied",locked:true,expectSend:false)
        run("public host denied",address:"https://example.com",expectSend:false)
        run("five-label numeric hostname denied",address:"http://x.10.0.0.3",expectSend:false)
        run("candidate path denied",address:host+"/other",expectSend:false)
        run("empty input denied",input:" ",expectSend:false)
        run("control character input denied",input:"x\ny",expectSend:false)
        run("oversized input denied",input:String(repeating:"a",count:121),expectSend:false)
        run("foreign widget denied",url:"https://example.com/overlay",expectSend:false)
        run("HTTP widget denied",url:"http://app.scoreholio.com/overlay",expectSend:false)
        run("stale page denied",pre:{_=$0.newPage()},expectSend:false)
        run("lost foreground/input denied",canSend:{false},expectSend:false)
        run("changed canonical address denied",response:{r in
            if r.url!.path=="/api/control-settings" {return (200,data(["lock":["enabled":true,"revision":"test-revision"],"sections":["vmix":["value":["address":"http://10.0.0.4:8088"]]]]))};return defaultResponse(r)
        },expectSend:false)
        run("changed PIN policy denied",response:{r in
            if r.url!.path=="/api/control-settings" {return (200,data(["lock":["enabled":true,"revision":"new-revision"],"sections":["vmix":["value":["address":host]]]]))};return defaultResponse(r)
        },expectSend:false)
        run("changed court widget denied",response:{r in
            if r.url!.path=="/api/live" {return (200,data(["courts":Array(repeating:["stale":false],count:4),"snapshot":["vmixAddress":host,"courts":Array(repeating:["kind":"assigned","widgetUrl":widget+"x"],count:4)]]))};return defaultResponse(r)
        },expectSend:false)
        run("stale court denied",response:{r in
            if r.url!.path=="/api/live" {return (200,data(["courts":Array(repeating:["stale":true],count:4),"snapshot":["vmixAddress":host,"courts":Array(repeating:["kind":"assigned","widgetUrl":widget],count:4)]]))};return defaultResponse(r)
        },expectSend:false)
        run("HTTP failure returned once",response:{r in r.url!.host=="10.0.0.3" ? (503,Data("Unavailable".utf8)):defaultResponse(r)},expectSend:true,expectStatus:503)
        run("Backend unavailable denied",response:{r in
            if r.url!.host=="10.0.0.2"{return (503,data(["error":"Offline"]))};return defaultResponse(r)
        },expectSend:false)
        var currentInput=true
        run("input edited during preflight denied",canSend:{currentInput},response:{r in
            if r.url!.path=="/api/control-settings"{DispatchQueue.main.async{currentInput=false}};return defaultResponse(r)
        },expectSend:false)
        var currentBroker:CourtlineSessionBroker?
        run("role revoked during preflight denied",pre:{currentBroker=$0},response:{r in
            if r.url!.path=="/api/control-settings"{DispatchQueue.main.async{currentBroker?.widgetTestInvalidate()}};return defaultResponse(r)
        },expectSend:false)
        let broker=CourtlineSessionBroker();var redirectAllowed=true
        broker.urlSession(URLSession.shared,task:URLSession.shared.dataTask(with:URL(string:host)!),willPerformHTTPRedirection:HTTPURLResponse(url:URL(string:host)!,statusCode:302,httpVersion:nil,headerFields:nil)!,newRequest:URLRequest(url:URL(string:"https://example.com")!)){redirectAllowed=$0 != nil}
        precondition(!redirectAllowed,"redirect must be refused");print("PASS redirect delegate rejects redirect")
        print("PASS actual Swift broker widget runtime harness; fake transport only")
    }
}
