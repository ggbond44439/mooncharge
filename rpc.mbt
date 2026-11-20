///|
/// Faults detected while decoding an OCPP JSON-RPC frame or payload.
#derive(Eq, @debug.Debug)
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
  InputTooLong(String, Int32, Int32)
  InvalidLimits(String)
  FieldTooLong(String, Int32, Int32)
  TooManyPayloadFields(Int32, Int32)
  UnsupportedProtocolVersion(OcppVersion)
}

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
    InputTooLong(context, limit, actual) =>
      "\{context} exceeds limit: \{actual} > \{limit} bytes"
    InvalidLimits(name) => "invalid frame limit '\{name}'"
    FieldTooLong(name, limit, actual) =>
      "\{name} exceeds limit: \{actual} > \{limit} bytes"
    TooManyPayloadFields(limit, actual) =>
      "payload has too many fields: \{actual} > \{limit}"
    UnsupportedProtocolVersion(version) =>
      "unsupported OCPP version \{version.label()}"
  }
}

///|
/// Resource limits applied before and during OCPP frame decoding.
#derive(Eq, @debug.Debug)
pub(all) struct FrameLimits {
  max_input_bytes : Int32
  max_nesting_depth : Int32
  max_message_id_bytes : Int32
  max_action_bytes : Int32
  max_payload_fields : Int32
  reject_duplicate_keys : Bool
}

///|
pub fn FrameLimits::default() -> FrameLimits {
  {
    max_input_bytes: 1024 * 1024,
    max_nesting_depth: 32,
    max_message_id_bytes: 256,
    max_action_bytes: 128,
    max_payload_fields: 256,
    reject_duplicate_keys: true,
  }
}

///|
pub fn FrameLimits::new(
  max_input_bytes~ : Int32 = 1024 * 1024,
  max_nesting_depth~ : Int32 = 32,
  max_message_id_bytes~ : Int32 = 256,
  max_action_bytes~ : Int32 = 128,
  max_payload_fields~ : Int32 = 256,
  reject_duplicate_keys~ : Bool = true,
) -> FrameLimits {
  {
    max_input_bytes,
    max_nesting_depth,
    max_message_id_bytes,
    max_action_bytes,
    max_payload_fields,
    reject_duplicate_keys,
  }
}

///|
pub fn FrameLimits::validate(self : FrameLimits) -> Result[Unit, ProtocolError] {
  if self.max_input_bytes <= 0 {
    return Err(InvalidLimits("max_input_bytes"))
  }
  if self.max_nesting_depth <= 0 {
    return Err(InvalidLimits("max_nesting_depth"))
  }
  if self.max_message_id_bytes <= 0 {
    return Err(InvalidLimits("max_message_id_bytes"))
  }
  if self.max_action_bytes <= 0 {
    return Err(InvalidLimits("max_action_bytes"))
  }
  if self.max_payload_fields <= 0 {
    return Err(InvalidLimits("max_payload_fields"))
  }
  Ok(())
}

///|
/// A JSON-RPC id. Numeric ids keep their exact source spelling.
#derive(Eq, @debug.Debug)
pub(all) enum MessageId {
  Text(String)
  Number(String)
  Null
}

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
#derive(Eq, @debug.Debug)
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
}

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
#derive(Eq, @debug.Debug)
pub(all) struct RpcError {
  code : RpcErrorCode
  description : String
  details : Json
}

///|
/// A decoded OCPP 1.6J WebSocket frame.
#derive(Eq, @debug.Debug)
pub(all) enum Frame {
  Call(MessageId, String, Json)
  CallResult(MessageId, Json)
  CallError(MessageId, RpcError)
}

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
fn utf8_size(text : String) -> Int32 {
  @utf8.encode(text).length()
}

///|
fn check_message_id(
  id : MessageId,
  limits : FrameLimits,
) -> Result[Unit, ProtocolError] {
  let size = match id {
    Text(value) | Number(value) => utf8_size(value)
    Null => 4
  }
  if size > limits.max_message_id_bytes {
    Err(FieldTooLong("messageId", limits.max_message_id_bytes, size))
  } else {
    Ok(())
  }
}

///|
fn check_payload(
  payload : Json,
  limits : FrameLimits,
) -> Result[Unit, ProtocolError] {
  let fields = match payload {
    Json::Object(fields) => fields
    _ => return Err(InvalidPayload)
  }
  if fields.length() > limits.max_payload_fields {
    Err(TooManyPayloadFields(limits.max_payload_fields, fields.length()))
  } else {
    Ok(())
  }
}

///|
/// Parses one OCPP WebSocket text frame with strict structural validation and
/// the default resource limits.
pub fn parse_frame(text : String) -> Result[Frame, ProtocolError] {
  parse_frame_with_limits(text, FrameLimits::default())
}

///|
/// Parses one OCPP WebSocket text frame with caller-provided resource limits.
pub fn parse_frame_with_limits(
  text : String,
  limits : FrameLimits,
) -> Result[Frame, ProtocolError] {
  match limits.validate() {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  if text.is_empty() {
    return Err(InvalidJson)
  }
  let input_size = utf8_size(text)
  if input_size > limits.max_input_bytes {
    return Err(InputTooLong("frame", limits.max_input_bytes, input_size))
  }
  let root = @json.parse(
    text,
    max_nesting_depth=limits.max_nesting_depth,
    reject_duplicate_keys=limits.reject_duplicate_keys,
    preserve_number_repr=true,
  ) catch {
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
      match check_message_id(id, limits) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      let action = match items[2] {
        Json::String(action) if !action.is_empty() => action
        _ => return Err(InvalidAction)
      }
      let action_size = utf8_size(action)
      if action_size > limits.max_action_bytes {
        return Err(FieldTooLong("action", limits.max_action_bytes, action_size))
      }
      let payload = match json_object_or_error(items[3]) {
        Ok(payload) => payload
        Err(error) => return Err(error)
      }
      match check_payload(payload, limits) {
        Ok(_) => ()
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
      match check_message_id(id, limits) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      let payload = match json_object_or_error(items[2]) {
        Ok(payload) => payload
        Err(error) => return Err(error)
      }
      match check_payload(payload, limits) {
        Ok(_) => ()
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
      match check_message_id(id, limits) {
        Ok(_) => ()
        Err(error) => return Err(error)
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
      match check_payload(details, limits) {
        Ok(_) => ()
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
