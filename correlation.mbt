///|
#derive(Eq, @debug.Debug)
pub(all) struct PendingCall {
  id : MessageId
  action : String
  request_direction : MessageDirection
  deadline : Int64
  active : Bool
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum CorrelatedResponse {
  Result(MessageId, String, Json)
  Error(MessageId, String, RpcError)
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum CorrelationError {
  InvalidMaxPending(Int32)
  UnsupportedVersion(OcppVersion)
  NullMessageId
  UnknownAction
  DuplicateMessageId(MessageId)
  TableFull(Int32)
  WrongDirection(MessageDirection, MessageDirection)
  NotAResponse
  UnknownMessageId(MessageId)
  Expired(MessageId)
  VersionMismatch(OcppVersion, OcppVersion)
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct PendingCallTable {
  version : OcppVersion
  max_pending : Int32
  calls : Array[PendingCall]
}

///|
pub fn PendingCallTable::new(
  version : OcppVersion,
  max_pending : Int32,
) -> Result[PendingCallTable, CorrelationError] {
  if max_pending <= 0 {
    return Err(InvalidMaxPending(max_pending))
  }
  if !version.is_supported() {
    return Err(UnsupportedVersion(version))
  }
  Ok({ version, max_pending, calls: [], })
}

///|
fn find_active_index(table : PendingCallTable, id : MessageId) -> Int32? {
  for index in 0..<table.calls.length() {
    let call = table.calls[index]
    if call.active && call.id == id {
      return Some(index)
    }
  }
  None
}

///|
pub fn PendingCallTable::pending_count(self : PendingCallTable) -> Int32 {
  let mut count = 0
  for call in self.calls {
    if call.active {
      count = count + 1
    }
  }
  count
}

///|
pub fn PendingCallTable::insert(
  self : PendingCallTable,
  id : MessageId,
  action : String,
  request_direction : MessageDirection,
  deadline : Int64,
) -> Result[Unit, CorrelationError] {
  if id == Null {
    return Err(NullMessageId)
  }
  let expected = match action_direction(action, true) {
    Ok(direction) => direction
    Err(_) => return Err(UnknownAction)
  }
  if expected != request_direction {
    return Err(WrongDirection(expected, request_direction))
  }
  if find_active_index(self, id) is Some(_) {
    return Err(DuplicateMessageId(id))
  }
  if self.pending_count() >= self.max_pending {
    return Err(TableFull(self.max_pending))
  }
  self.calls.push({ id, action, request_direction, deadline, active: true, })
  Ok(())
}

///|
pub fn PendingCallTable::expire(
  self : PendingCallTable,
  now : Int64,
) -> Array[PendingCall] {
  let expired : Array[PendingCall] = []
  for index in 0..<self.calls.length() {
    let call = self.calls[index]
    if call.active && now >= call.deadline {
      expired.push(call)
      self.calls[index] = { ..call, active: false, }
    }
  }
  expired
}

///|
pub fn PendingCallTable::complete(
  self : PendingCallTable,
  frame : Frame,
  received_at : MessageDirection,
  now : Int64,
) -> Result[CorrelatedResponse, CorrelationError] {
  let (id, response) = match frame {
    CallResult(id, payload) => (id, Result(id, "", payload))
    CallError(id, error) => (id, Error(id, "", error))
    Call(_, _, _) => return Err(NotAResponse)
  }
  let index = match find_active_index(self, id) {
    Some(index) => index
    None => return Err(UnknownMessageId(id))
  }
  let call = self.calls[index]
  if now >= call.deadline {
    self.calls[index] = { ..call, active: false, }
    return Err(Expired(id))
  }
  let expected = match action_direction(call.action, false) {
    Ok(direction) => direction
    Err(_) => return Err(UnknownAction)
  }
  if expected != received_at {
    return Err(WrongDirection(expected, received_at))
  }
  self.calls[index] = { ..call, active: false, }
  match response {
    Result(id, _, payload) => Ok(Result(id, call.action, payload))
    Error(id, _, error) => Ok(Error(id, call.action, error))
  }
}

///|
pub fn PendingCallTable::complete_versioned(
  self : PendingCallTable,
  value : VersionedFrame,
  received_at : MessageDirection,
  now : Int64,
) -> Result[CorrelatedResponse, CorrelationError] {
  if value.version != self.version {
    Err(VersionMismatch(self.version, value.version))
  } else {
    self.complete(value.frame, received_at, now)
  }
}
