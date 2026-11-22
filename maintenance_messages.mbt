///|
fn required_nonempty_string(
  value : Json,
  name : String,
) -> String raise ProtocolFailure {
  let text = required_string(value, name)
  if text.is_empty() {
    refuse(InvalidField(name))
  }
  text
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct GetDiagnosticsRequest {
  location : String
  retries : Int32?
  retry_interval : Int32?
  start_time : String?
  stop_time : String?
}

///|
fn parse_get_diagnostics_request(
  value : Json,
) -> GetDiagnosticsRequest raise ProtocolFailure {
  {
    location: required_nonempty_string(value, "location"),
    retries: optional_nonnegative_int(value, "retries"),
    retry_interval: optional_nonnegative_int(value, "retryInterval"),
    start_time: optional_string(value, "startTime"),
    stop_time: optional_string(value, "stopTime"),
  }
}

///|
pub fn GetDiagnosticsRequest::from_json(
  value : Json,
) -> Result[GetDiagnosticsRequest, ProtocolError] {
  result_of(() => parse_get_diagnostics_request(value))
}

///|
pub fn GetDiagnosticsRequest::to_json(self : GetDiagnosticsRequest) -> Json {
  let fields : Map[String, Json] = { "location": Json::string(self.location) }
  match self.retries {
    Some(value) => fields.set("retries", int_json(value))
    None => ()
  }
  match self.retry_interval {
    Some(value) => fields.set("retryInterval", int_json(value))
    None => ()
  }
  set_optional_string(fields, "startTime", self.start_time)
  set_optional_string(fields, "stopTime", self.stop_time)
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct GetDiagnosticsResponse {
  file_name : String?
}

///|
fn parse_get_diagnostics_response(
  value : Json,
) -> GetDiagnosticsResponse raise ProtocolFailure {
  { file_name: optional_string(value, "fileName"), }
}

///|
pub fn GetDiagnosticsResponse::from_json(
  value : Json,
) -> Result[GetDiagnosticsResponse, ProtocolError] {
  result_of(() => parse_get_diagnostics_response(value))
}

///|
pub fn GetDiagnosticsResponse::to_json(self : GetDiagnosticsResponse) -> Json {
  let fields : Map[String, Json] = Map([])
  set_optional_string(fields, "fileName", self.file_name)
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct UpdateFirmwareRequest {
  location : String
  retrieve_date : String
  retries : Int32?
  retry_interval : Int32?
}

///|
fn parse_update_firmware_request(
  value : Json,
) -> UpdateFirmwareRequest raise ProtocolFailure {
  {
    location: required_nonempty_string(value, "location"),
    retrieve_date: required_nonempty_string(value, "retrieveDate"),
    retries: optional_nonnegative_int(value, "retries"),
    retry_interval: optional_nonnegative_int(value, "retryInterval"),
  }
}

///|
pub fn UpdateFirmwareRequest::from_json(
  value : Json,
) -> Result[UpdateFirmwareRequest, ProtocolError] {
  result_of(() => parse_update_firmware_request(value))
}

///|
pub fn UpdateFirmwareRequest::to_json(self : UpdateFirmwareRequest) -> Json {
  let fields : Map[String, Json] = {
    "location": Json::string(self.location),
    "retrieveDate": Json::string(self.retrieve_date),
  }
  match self.retries {
    Some(value) => fields.set("retries", int_json(value))
    None => ()
  }
  match self.retry_interval {
    Some(value) => fields.set("retryInterval", int_json(value))
    None => ()
  }
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub struct UpdateFirmwareResponse {
  marker : Unit
}

///|
pub fn UpdateFirmwareResponse::new() -> UpdateFirmwareResponse {
  { marker: (), }
}

///|
fn parse_update_firmware_response(
  value : Json,
) -> UpdateFirmwareResponse raise ProtocolFailure {
  ensure_empty_object(value)
  UpdateFirmwareResponse::new()
}

///|
pub fn UpdateFirmwareResponse::from_json(
  value : Json,
) -> Result[UpdateFirmwareResponse, ProtocolError] {
  result_of(() => parse_update_firmware_response(value))
}

///|
pub fn UpdateFirmwareResponse::to_json(self : UpdateFirmwareResponse) -> Json {
  ignore(self)
  empty_object()
}
