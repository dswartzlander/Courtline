import Foundation
@main struct VerificationDetailRuntime {
 static func main() {
  let id="00000000-0000-0000-0000-000000000001"
  let secret="DO_NOT_LOG_credential_OR_response"
  let e=NSError(domain:NSURLErrorDomain,code:-1001,userInfo:[NSLocalizedDescriptionKey:secret,"url":secret])
  let detail=CourtlineSessionBroker.verificationDetail(status:0,json:["secret":secret],error:e,expectedID:id)
  precondition(detail=="Stage: identity request failed; NSURLErrorDomain -1001")
  let unknown=CourtlineSessionBroker.verificationDetail(status:0,json:[:],error:NSError(domain:secret,code:7),expectedID:id)
  precondition(unknown=="Stage: identity request failed; other 7")
  precondition(CourtlineSessionBroker.verificationDetail(status:403,json:["error":secret],error:nil,expectedID:id)=="Stage: identity HTTP; status 403")
  precondition(CourtlineSessionBroker.verificationDetail(status:200,json:[:],error:nil,expectedID:id)=="Stage: identity schema rejected")
  precondition(CourtlineSessionBroker.verificationDetail(status:200,json:["version":1,"backendId":secret],error:nil,expectedID:id)=="Stage: Backend identity mismatch")
  precondition(CourtlineSessionBroker.verificationDetail(status:200,json:["version":1,"backendId":id],error:nil,expectedID:id)=="Stage: identity verified")
  print("PASS fixed bounded verification diagnostics without credential/response leak")
 }
}
