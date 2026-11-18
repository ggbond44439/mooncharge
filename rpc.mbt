///|
/// Faults detected while decoding an OCPP JSON-RPC frame or payload.
pub(all) enum ProtocolError {
  InvalidJson
  FrameMustBeArray
  UnsupportedFrameType(Int32)
  InvalidFrameLength(Int32)
  InvalidMessageId
  InvalidAction
  InvalidPayload
  MissingField(String)
  InvalidField(String)
  UnsupportedValue(String, String)
} derive(Eq, @debug.Debug)

///|
pub fn ProtocolError::message(self : ProtocolError) -> String {
  match self {
    InvalidJson => "frame is not valid JSON"
    FrameMustBeArray => "OCPP frame must be a JSON array"
    UnsupportedFrameType(code) => "unsupported OCPP frame type \{code}"
    InvalidFrameLength(length) => "invalid OCPP frame length \{length}"
    InvalidMessageId => "message id must be a string, number, or null"
    InvalidAction => "action must be a non-empty string"
    InvalidPayload => "payload must be a JSON object"
    MissingField(name) => "missing required field '\{name}'"
    InvalidField(name) => "invalid value for field '\{name}'"
    UnsupportedValue(field, value) =>
      "unsupported value '\{value}' for field '\{field}'"
  }
}

///|
/// A JSON-RPC id. Numeric ids keep their exact source spelling.
pub(all) enum MessageId {
  Text(String)
  Number(String)
  Null
} derive(Eq, @debug.Debug)

///|
pub fn MessageId::to_json(self : MessageId) -> Json {
  match self {
    Text(value) => Json::string(value)
    Number(repr) => @json.parse(repr) catch { _ => Json::null() }
    Null => Json::null()
  }
}

///|
fn message_id_from_json(value : Json) -> MessageId? {
  match value {
    Json::String(text) => Some(Text(text))
    Json::Number(_, ..) => Some(Number(value.stringify()))
    Json::Null => Some(Null)
    _ => None
  }
}

///|
/// OCPP-defined JSON-RPC error codes plus forward-compatible unknown codes.
pub(all) enum RpcErrorCode {
  NotImplemented
  NotSupported
  InternalError
  ProtocolError
  SecurityError
  FormationViolation
  PropertyConstraintViolation
  OccurrenceConstraintViolation
  TypeConstraintViolation
  GenericError
  Unknown(String)
} derive(Eq, @debug.Debug)

///|
pub fn RpcErrorCode::to_string(self : RpcErrorCode) -> String {
  match self {
    NotImplemented => "NotImplemented"
    NotSupported => "NotSupported"
    InternalError => "InternalError"
    ProtocolError => "ProtocolError"
    SecurityError => "SecurityError"
    FormationViolation => "FormationViolation"
    PropertyConstraintViolation => "PropertyConstraintViolation"
    OccurrenceConstraintViolation => "OccurrenceConstraintViolation"
    TypeConstraintViolation => "TypeConstraintViolation"
    GenericError => "GenericError"
    Unknown(value) => value
  }
}

///|
pub fn RpcErrorCode::parse(value : String) -> RpcErrorCode {
  match value {
    "NotImplemented" => NotImplemented
    "NotSupported" => NotSupported
    "InternalError" => InternalError
    "ProtocolError" => ProtocolError
    "SecurityError" => SecurityError
    "FormationViolation" => FormationViolation
    "PropertyConstraintViolation" => PropertyConstraintViolation
    "OccurrenceConstraintViolation" => OccurrenceConstraintViolation
    "TypeConstraintViolation" => TypeConstraintViolation
    "GenericError" => GenericError
    _ => Unknown(value)
  }
}

///|
pub(all) struct RpcError {
  code : RpcErrorCode
  description : String
  details : Json
} derive(Eq, @debug.Debug)

///|
/// A decoded OCPP 1.6J WebSocket frame.
pub(all) enum Frame {
  Call(MessageId, String, Json)
  CallResult(MessageId, Json)
  CallError(MessageId, RpcError)
} derive(Eq, @debug.Debug)

///|
pub fn Frame::to_json(self : Frame) -> Json {
  match self {
    Call(id, action, payload) =>
      Json::array([
        Json::number(2.0, repr="2"),
        id.to_json(),
        Json::string(action),
        payload,
      ])
    CallResult(id, payload) =>
      Json::array([Json::number(3.0, repr="3"), id.to_json(), payload])
    CallError(id, error) =>
      Json::array([
        Json::number(4.0, repr="4"),
        id.to_json(),
        Json::string(error.code.to_string()),
        Json::string(error.description),
        error.details,
      ])
  }
}

///|
pub fn Frame::encode(self : Frame) -> String {
  self.to_json().stringify()
}

///|
fn json_object_or_error(value : Json) -> Result[Json, ProtocolError] {
  match value {
    Json::Object(_) => Ok(value)
    _ => Err(InvalidPayload)
  }
}

///|
/// Parses one OCPP WebSocket text frame with strict structural validation.
pub fn parse_frame(text : String) -> Result[Frame, ProtocolError] {
  if text.is_empty() {
    return Err(InvalidJson)
  }
  let root = @json.parse(text, max_nesting_depth=64, preserve_number_repr=true) catch {
    _ => return Err(InvalidJson)
  }
  let items = match root {
    Json::Array(items) => items
    _ => return Err(FrameMustBeArray)
  }
  if items.length() < 3 {
    return Err(InvalidFrameLength(items.length()))
  }
  let frame_type = match items[0] {
    Json::Number(number, ..) => number.to_int()
    _ => return Err(UnsupportedFrameType(-1))
  }
  match frame_type {
    2 => {
      if items.length() != 4 {
        return Err(InvalidFrameLength(items.length()))
      }
      let id = match message_id_from_json(items[1]) {
        Some(id) => id
        None => return Err(InvalidMessageId)
      }
      let action = match items[2] {
        Json::String(action) if !action.is_empty() => action
        _ => return Err(InvalidAction)
      }
      let payload = match json_object_or_error(items[3]) {
        Ok(payload) => payload
        Err(error) => return Err(error)
      }
      Ok(Call(id, action, payload))
    }
    3 => {
      if items.length() != 3 {
        return Err(InvalidFrameLength(items.length()))
      }
      let id = match message_id_from_json(items[1]) {
        Some(id) => id
        None => return Err(InvalidMessageId)
      }
      let payload = match json_object_or_error(items[2]) {
        Ok(payload) => payload
        Err(error) => return Err(error)
      }
      Ok(CallResult(id, payload))
    }
    4 => {
      if items.length() != 5 {
        return Err(InvalidFrameLength(items.length()))
      }
      let id = match message_id_from_json(items[1]) {
        Some(id) => id
        None => return Err(InvalidMessageId)
      }
      let code = match items[2] {
        Json::String(code) if !code.is_empty() => RpcErrorCode::parse(code)
        _ => return Err(InvalidField("errorCode"))
      }
      let description = match items[3] {
        Json::String(description) => description
        _ => return Err(InvalidField("errorDescription"))
      }
      let details = match json_object_or_error(items[4]) {
        Ok(details) => details
        Err(error) => return Err(error)
      }
      Ok(CallError(id, { code, description, details, }))
    }
    other => Err(UnsupportedFrameType(other))
  }
}

///|
pub impl Show for ProtocolError with fn output(self, logger) {
  logger.write_string("mooncharge: \{self.message()}")
}
