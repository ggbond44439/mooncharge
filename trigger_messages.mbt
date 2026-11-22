///|
#derive(Eq, @debug.Debug)
pub(all) enum TriggerMessageName {
  BootNotification
  DiagnosticsStatusNotification
  FirmwareStatusNotification
  Heartbeat
  MeterValues
  StatusNotification
}

///|
fn trigger_message_name(
  value : String,
) -> TriggerMessageName raise ProtocolFailure {
  match value {
    "BootNotification" => BootNotification
    "DiagnosticsStatusNotification" => DiagnosticsStatusNotification
    "FirmwareStatusNotification" => FirmwareStatusNotification
    "Heartbeat" => Heartbeat
    "MeterValues" => MeterValues
    "StatusNotification" => StatusNotification
    _ => refuse(UnsupportedValue("requestedMessage", value))
  }
}

///|
fn trigger_message_name_text(value : TriggerMessageName) -> String {
  match value {
    BootNotification => "BootNotification"
    DiagnosticsStatusNotification => "DiagnosticsStatusNotification"
    FirmwareStatusNotification => "FirmwareStatusNotification"
    Heartbeat => "Heartbeat"
    MeterValues => "MeterValues"
    StatusNotification => "StatusNotification"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct TriggerMessageRequest {
  requested_message : TriggerMessageName
  connector_id : Int32?
}

///|
fn parse_trigger_message_request(
  value : Json,
) -> TriggerMessageRequest raise ProtocolFailure {
  {
    requested_message: trigger_message_name(
      required_string(value, "requestedMessage"),
    ),
    connector_id: optional_nonnegative_int(value, "connectorId"),
  }
}

///|
pub fn TriggerMessageRequest::from_json(
  value : Json,
) -> Result[TriggerMessageRequest, ProtocolError] {
  result_of(() => parse_trigger_message_request(value))
}

///|
pub fn TriggerMessageRequest::to_json(self : TriggerMessageRequest) -> Json {
  let fields : Map[String, Json] = {
    "requestedMessage": Json::string(
      trigger_message_name_text(self.requested_message),
    ),
  }
  match self.connector_id {
    Some(value) => fields.set("connectorId", int_json(value))
    None => ()
  }
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum TriggerMessageStatus {
  Accepted
  Rejected
  NotImplemented
}

///|
fn parse_trigger_message_status(
  value : String,
) -> TriggerMessageStatus raise ProtocolFailure {
  match value {
    "Accepted" => Accepted
    "Rejected" => Rejected
    "NotImplemented" => NotImplemented
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
fn trigger_message_status_text(value : TriggerMessageStatus) -> String {
  match value {
    Accepted => "Accepted"
    Rejected => "Rejected"
    NotImplemented => "NotImplemented"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct TriggerMessageResponse {
  status : TriggerMessageStatus
}

///|
fn parse_trigger_message_response(
  value : Json,
) -> TriggerMessageResponse raise ProtocolFailure {
  { status: parse_trigger_message_status(required_string(value, "status")), }
}

///|
pub fn TriggerMessageResponse::from_json(
  value : Json,
) -> Result[TriggerMessageResponse, ProtocolError] {
  result_of(() => parse_trigger_message_response(value))
}

///|
pub fn TriggerMessageResponse::to_json(self : TriggerMessageResponse) -> Json {
  Json::object({
    "status": Json::string(trigger_message_status_text(self.status)),
  })
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum ExtendedTriggerMessageName {
  BootNotification
  LogStatusNotification
  FirmwareStatusNotification
  Heartbeat
  MeterValues
  SignChargePointCertificate
  StatusNotification
}

///|
fn parse_extended_trigger_name(
  value : String,
) -> ExtendedTriggerMessageName raise ProtocolFailure {
  match value {
    "BootNotification" => BootNotification
    "LogStatusNotification" => LogStatusNotification
    "FirmwareStatusNotification" => FirmwareStatusNotification
    "Heartbeat" => Heartbeat
    "MeterValues" => MeterValues
    "SignChargePointCertificate" => SignChargePointCertificate
    "StatusNotification" => StatusNotification
    _ => refuse(UnsupportedValue("requestedMessage", value))
  }
}

///|
fn extended_trigger_name_text(value : ExtendedTriggerMessageName) -> String {
  match value {
    BootNotification => "BootNotification"
    LogStatusNotification => "LogStatusNotification"
    FirmwareStatusNotification => "FirmwareStatusNotification"
    Heartbeat => "Heartbeat"
    MeterValues => "MeterValues"
    SignChargePointCertificate => "SignChargePointCertificate"
    StatusNotification => "StatusNotification"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ExtendedTriggerMessageRequest {
  requested_message : ExtendedTriggerMessageName
  connector_id : Int32?
}

///|
fn parse_extended_trigger_message_request(
  value : Json,
) -> ExtendedTriggerMessageRequest raise ProtocolFailure {
  {
    requested_message: parse_extended_trigger_name(
      required_string(value, "requestedMessage"),
    ),
    connector_id: optional_nonnegative_int(value, "connectorId"),
  }
}

///|
pub fn ExtendedTriggerMessageRequest::from_json(
  value : Json,
) -> Result[ExtendedTriggerMessageRequest, ProtocolError] {
  result_of(() => parse_extended_trigger_message_request(value))
}

///|
pub fn ExtendedTriggerMessageRequest::to_json(
  self : ExtendedTriggerMessageRequest,
) -> Json {
  let fields : Map[String, Json] = {
    "requestedMessage": Json::string(
      extended_trigger_name_text(self.requested_message),
    ),
  }
  match self.connector_id {
    Some(value) => fields.set("connectorId", int_json(value))
    None => ()
  }
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ExtendedTriggerMessageResponse {
  status : TriggerMessageStatus
}

///|
fn parse_extended_trigger_message_response(
  value : Json,
) -> ExtendedTriggerMessageResponse raise ProtocolFailure {
  { status: parse_trigger_message_status(required_string(value, "status")), }
}

///|
pub fn ExtendedTriggerMessageResponse::from_json(
  value : Json,
) -> Result[ExtendedTriggerMessageResponse, ProtocolError] {
  result_of(() => parse_extended_trigger_message_response(value))
}

///|
pub fn ExtendedTriggerMessageResponse::to_json(
  self : ExtendedTriggerMessageResponse,
) -> Json {
  Json::object({
    "status": Json::string(trigger_message_status_text(self.status)),
  })
}

///|
fn required_positive_int(
  value : Json,
  name : String,
) -> Int32 raise ProtocolFailure {
  let number = required_nonnegative_int(value, name)
  if number == 0 {
    refuse(InvalidField(name))
  }
  number
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct GetCompositeScheduleRequest {
  connector_id : Int32
  duration : Int32
  charging_rate_unit : ChargingRateUnit?
}

///|
fn parse_get_composite_schedule_request(
  value : Json,
) -> GetCompositeScheduleRequest raise ProtocolFailure {
  let unit = match optional_string(value, "chargingRateUnit") {
    None => None
    Some(text) => Some(parse_rate_unit(text))
  }
  {
    connector_id: required_nonnegative_int(value, "connectorId"),
    duration: required_positive_int(value, "duration"),
    charging_rate_unit: unit,
  }
}

///|
pub fn GetCompositeScheduleRequest::from_json(
  value : Json,
) -> Result[GetCompositeScheduleRequest, ProtocolError] {
  result_of(() => parse_get_composite_schedule_request(value))
}

///|
pub fn GetCompositeScheduleRequest::to_json(
  self : GetCompositeScheduleRequest,
) -> Json {
  let fields : Map[String, Json] = {
    "connectorId": int_json(self.connector_id),
    "duration": int_json(self.duration),
  }
  match self.charging_rate_unit {
    Some(unit) =>
      fields.set("chargingRateUnit", Json::string(rate_unit_name(unit)))
    None => ()
  }
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum GetCompositeScheduleStatus {
  Accepted
  Rejected
}

///|
fn parse_composite_schedule_status(
  value : String,
) -> GetCompositeScheduleStatus raise ProtocolFailure {
  match value {
    "Accepted" => Accepted
    "Rejected" => Rejected
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
fn composite_schedule_status_text(value : GetCompositeScheduleStatus) -> String {
  match value {
    Accepted => "Accepted"
    Rejected => "Rejected"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct GetCompositeScheduleResponse {
  status : GetCompositeScheduleStatus
  connector_id : Int32?
  schedule : ChargingSchedule?
}

///|
fn parse_get_composite_schedule_response(
  value : Json,
) -> GetCompositeScheduleResponse raise ProtocolFailure {
  let fields = match value {
    Json::Object(fields) => fields
    _ => refuse(InvalidPayload)
  }
  let schedule = match fields.get("schedule") {
    None | Some(Json::Null) => None
    Some(field) => Some(parse_charging_schedule(field))
  }
  {
    status: parse_composite_schedule_status(required_string(value, "status")),
    connector_id: optional_nonnegative_int(value, "connectorId"),
    schedule,
  }
}

///|
pub fn GetCompositeScheduleResponse::from_json(
  value : Json,
) -> Result[GetCompositeScheduleResponse, ProtocolError] {
  result_of(() => parse_get_composite_schedule_response(value))
}

///|
pub fn GetCompositeScheduleResponse::to_json(
  self : GetCompositeScheduleResponse,
) -> Json {
  let fields : Map[String, Json] = {
    "status": Json::string(composite_schedule_status_text(self.status)),
  }
  match self.connector_id {
    Some(value) => fields.set("connectorId", int_json(value))
    None => ()
  }
  match self.schedule {
    Some(value) => fields.set("schedule", value.to_json())
    None => ()
  }
  Json::object(fields)
}
