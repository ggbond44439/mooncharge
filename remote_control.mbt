///|
#derive(Eq, @debug.Debug)
pub(all) enum RemoteCommandStatus {
  Accepted
  Rejected
}

///|
fn remote_command_status(
  value : String,
) -> RemoteCommandStatus raise ProtocolFailure {
  match value {
    "Accepted" => Accepted
    "Rejected" => Rejected
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
fn remote_command_status_name(value : RemoteCommandStatus) -> String {
  match value {
    Accepted => "Accepted"
    Rejected => "Rejected"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct RemoteStartTransactionRequest {
  id_tag : String
  connector_id : Int32?
  charging_profile : ChargingProfile?
}

///|
fn parse_remote_start(
  value : Json,
) -> RemoteStartTransactionRequest raise ProtocolFailure {
  let id_tag = required_string(value, "idTag")
  if id_tag.is_empty() {
    refuse(InvalidField("idTag"))
  }
  let fields = match value {
    Json::Object(fields) => fields
    _ => refuse(InvalidPayload)
  }
  let charging_profile = match fields.get("chargingProfile") {
    None | Some(Json::Null) => None
    Some(profile) => Some(parse_charging_profile(profile))
  }
  {
    id_tag,
    connector_id: optional_nonnegative_int(value, "connectorId"),
    charging_profile,
  }
}

///|
pub fn RemoteStartTransactionRequest::from_json(
  value : Json,
) -> Result[RemoteStartTransactionRequest, ProtocolError] {
  result_of(() => parse_remote_start(value))
}

///|
pub fn RemoteStartTransactionRequest::to_json(
  self : RemoteStartTransactionRequest,
) -> Json {
  let fields : Map[String, Json] = { "idTag": Json::string(self.id_tag) }
  match self.connector_id {
    Some(value) => fields.set("connectorId", int_json(value))
    None => ()
  }
  match self.charging_profile {
    Some(profile) => fields.set("chargingProfile", profile.to_json())
    None => ()
  }
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct RemoteStartTransactionResponse {
  status : RemoteCommandStatus
}

///|
fn parse_remote_start_response(
  value : Json,
) -> RemoteStartTransactionResponse raise ProtocolFailure {
  { status: remote_command_status(required_string(value, "status")), }
}

///|
pub fn RemoteStartTransactionResponse::from_json(
  value : Json,
) -> Result[RemoteStartTransactionResponse, ProtocolError] {
  result_of(() => parse_remote_start_response(value))
}

///|
pub fn RemoteStartTransactionResponse::to_json(
  self : RemoteStartTransactionResponse,
) -> Json {
  Json::object({
    "status": Json::string(remote_command_status_name(self.status)),
  })
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct RemoteStopTransactionRequest {
  transaction_id : Int32
}

///|
fn parse_remote_stop(
  value : Json,
) -> RemoteStopTransactionRequest raise ProtocolFailure {
  { transaction_id: required_nonnegative_int(value, "transactionId"), }
}

///|
pub fn RemoteStopTransactionRequest::from_json(
  value : Json,
) -> Result[RemoteStopTransactionRequest, ProtocolError] {
  result_of(() => parse_remote_stop(value))
}

///|
pub fn RemoteStopTransactionRequest::to_json(
  self : RemoteStopTransactionRequest,
) -> Json {
  Json::object({ "transactionId": int_json(self.transaction_id) })
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct RemoteStopTransactionResponse {
  status : RemoteCommandStatus
}

///|
fn parse_remote_stop_response(
  value : Json,
) -> RemoteStopTransactionResponse raise ProtocolFailure {
  { status: remote_command_status(required_string(value, "status")), }
}

///|
pub fn RemoteStopTransactionResponse::from_json(
  value : Json,
) -> Result[RemoteStopTransactionResponse, ProtocolError] {
  result_of(() => parse_remote_stop_response(value))
}

///|
pub fn RemoteStopTransactionResponse::to_json(
  self : RemoteStopTransactionResponse,
) -> Json {
  Json::object({
    "status": Json::string(remote_command_status_name(self.status)),
  })
}
