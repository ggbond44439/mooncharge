///|
#derive(Eq, @debug.Debug)
pub(all) enum ResetType {
  Hard
  Soft
}

///|
fn parse_reset_type(value : String) -> ResetType raise ProtocolFailure {
  match value {
    "Hard" => Hard
    "Soft" => Soft
    _ => refuse(UnsupportedValue("type", value))
  }
}

///|
fn reset_type_name(value : ResetType) -> String {
  match value {
    Hard => "Hard"
    Soft => "Soft"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ResetRequest {
  kind : ResetType
}

///|
fn parse_reset_request(value : Json) -> ResetRequest raise ProtocolFailure {
  { kind: parse_reset_type(required_string(value, "type")), }
}

///|
pub fn ResetRequest::from_json(
  value : Json,
) -> Result[ResetRequest, ProtocolError] {
  result_of(() => parse_reset_request(value))
}

///|
pub fn ResetRequest::to_json(self : ResetRequest) -> Json {
  Json::object({ "type": Json::string(reset_type_name(self.kind)) })
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ResetResponse {
  status : RemoteCommandStatus
}

///|
fn parse_reset_response(value : Json) -> ResetResponse raise ProtocolFailure {
  { status: remote_command_status(required_string(value, "status")), }
}

///|
pub fn ResetResponse::from_json(
  value : Json,
) -> Result[ResetResponse, ProtocolError] {
  result_of(() => parse_reset_response(value))
}

///|
pub fn ResetResponse::to_json(self : ResetResponse) -> Json {
  Json::object({
    "status": Json::string(remote_command_status_name(self.status)),
  })
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum AvailabilityType {
  Operative
  Inoperative
}

///|
fn parse_availability_type(
  value : String,
) -> AvailabilityType raise ProtocolFailure {
  match value {
    "Operative" => Operative
    "Inoperative" => Inoperative
    _ => refuse(UnsupportedValue("type", value))
  }
}

///|
fn availability_type_name(value : AvailabilityType) -> String {
  match value {
    Operative => "Operative"
    Inoperative => "Inoperative"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ChangeAvailabilityRequest {
  connector_id : Int32
  kind : AvailabilityType
}

///|
fn parse_change_availability(
  value : Json,
) -> ChangeAvailabilityRequest raise ProtocolFailure {
  {
    connector_id: required_nonnegative_int(value, "connectorId"),
    kind: parse_availability_type(required_string(value, "type")),
  }
}

///|
pub fn ChangeAvailabilityRequest::from_json(
  value : Json,
) -> Result[ChangeAvailabilityRequest, ProtocolError] {
  result_of(() => parse_change_availability(value))
}

///|
pub fn ChangeAvailabilityRequest::to_json(
  self : ChangeAvailabilityRequest,
) -> Json {
  Json::object({
    "connectorId": int_json(self.connector_id),
    "type": Json::string(availability_type_name(self.kind)),
  })
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ChangeAvailabilityResponse {
  status : RemoteCommandStatus
}

///|
fn parse_change_availability_response(
  value : Json,
) -> ChangeAvailabilityResponse raise ProtocolFailure {
  { status: remote_command_status(required_string(value, "status")), }
}

///|
pub fn ChangeAvailabilityResponse::from_json(
  value : Json,
) -> Result[ChangeAvailabilityResponse, ProtocolError] {
  result_of(() => parse_change_availability_response(value))
}

///|
pub fn ChangeAvailabilityResponse::to_json(
  self : ChangeAvailabilityResponse,
) -> Json {
  Json::object({
    "status": Json::string(remote_command_status_name(self.status)),
  })
}
