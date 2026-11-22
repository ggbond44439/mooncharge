///|
#derive(Eq, @debug.Debug)
pub(all) enum RouterError {
  NotACall
  InvalidMaxSeen(Int32)
  UnsupportedVersion(OcppVersion)
  DuplicateRequest(MessageId)
  InvalidHandlerPayload
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct OcppRequestRouter {
  version : OcppVersion
  max_seen_ids : Int32
  mut seen_ids : Array[String]
}

///|
pub fn OcppRequestRouter::new(
  version : OcppVersion,
  max_seen_ids : Int32,
) -> Result[OcppRequestRouter, RouterError] {
  if !version.is_supported() {
    return Err(UnsupportedVersion(version))
  }
  if max_seen_ids <= 0 {
    return Err(InvalidMaxSeen(max_seen_ids))
  }
  Ok({ version, max_seen_ids, seen_ids: [], })
}

///|
fn router_message_key(id : MessageId) -> String {
  match id {
    Text(value) => "s:\{value}"
    Number(value) => "n:\{value}"
    Null => "z:"
  }
}

///|
fn remember_request(
  router : OcppRequestRouter,
  id : MessageId,
) -> Result[Unit, RouterError] {
  let key = router_message_key(id)
  if router.seen_ids.contains(key) {
    return Err(DuplicateRequest(id))
  }
  if router.seen_ids.length() >= router.max_seen_ids {
    ignore(router.seen_ids.remove(0))
  }
  router.seen_ids.push(key)
  Ok(())
}

///|
fn router_error_response(id : MessageId, error : DispatchError) -> Frame {
  let (code, description) = match error {
    InvalidAction(protocol_error) =>
      (FormationViolation, protocol_error.message())
    InvalidPayload(protocol_error) =>
      (PropertyConstraintViolation, protocol_error.message())
    WrongDirection(_, _) =>
      (FormationViolation, "request has the wrong OCPP direction")
    UnsupportedVersion(_) =>
      (NotSupported, "the request protocol version is not supported")
    NotACall => (FormationViolation, "request must be a CALL frame")
  }
  CallError(id, { code, description, details: empty_object(), })
}

///|
pub fn OcppRequestRouter::handle(
  self : OcppRequestRouter,
  frame : Frame,
  received_at : MessageDirection,
  handler : (TypedCall) -> Result[Json, RpcError],
) -> Result[Frame, RouterError] {
  let id = match frame {
    Call(id, _, _) => id
    _ => return Err(NotACall)
  }
  match remember_request(self, id) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let call = match dispatch_call(frame, received_at) {
    Ok(call) => call
    Err(error) => return Ok(router_error_response(id, error))
  }
  let response = match handler(call) {
    Ok(payload) =>
      match payload {
        Json::Object(_) => CallResult(id, payload)
        _ => return Err(InvalidHandlerPayload)
      }
    Err(error) => CallError(id, error)
  }
  Ok(response)
}

///|
pub fn OcppRequestRouter::seen_count(self : OcppRequestRouter) -> Int32 {
  self.seen_ids.length()
}

///|
pub fn OcppRequestRouter::clear_seen(self : OcppRequestRouter) -> Unit {
  self.seen_ids = []
}
