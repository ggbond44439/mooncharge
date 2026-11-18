///|
#derive(Eq, @debug.Debug)
pub(all) enum ChargingProfileStatus {
  Accepted
  Rejected
  NotSupported
}

///|
fn parse_charging_profile_status(
  value : String,
) -> ChargingProfileStatus raise ProtocolFailure {
  match value {
    "Accepted" => Accepted
    "Rejected" => Rejected
    "NotSupported" => NotSupported
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
fn charging_profile_status_name(value : ChargingProfileStatus) -> String {
  match value {
    Accepted => "Accepted"
    Rejected => "Rejected"
    NotSupported => "NotSupported"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct SetChargingProfileRequest {
  connector_id : Int32
  cs_charging_profiles : ChargingProfile
}

///|
fn parse_set_charging_profile(
  value : Json,
) -> SetChargingProfileRequest raise ProtocolFailure {
  {
    connector_id: required_nonnegative_int(value, "connectorId"),
    cs_charging_profiles: parse_charging_profile(
      required_object(value, "csChargingProfiles"),
    ),
  }
}

///|
pub fn SetChargingProfileRequest::from_json(
  value : Json,
) -> Result[SetChargingProfileRequest, ProtocolError] {
  result_of(() => parse_set_charging_profile(value))
}

///|
pub fn SetChargingProfileRequest::to_json(
  self : SetChargingProfileRequest,
) -> Json {
  Json::object({
    "connectorId": int_json(self.connector_id),
    "csChargingProfiles": self.cs_charging_profiles.to_json(),
  })
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct SetChargingProfileResponse {
  status : ChargingProfileStatus
}

///|
fn parse_set_charging_profile_response(
  value : Json,
) -> SetChargingProfileResponse raise ProtocolFailure {
  { status: parse_charging_profile_status(required_string(value, "status")), }
}

///|
pub fn SetChargingProfileResponse::from_json(
  value : Json,
) -> Result[SetChargingProfileResponse, ProtocolError] {
  result_of(() => parse_set_charging_profile_response(value))
}

///|
pub fn SetChargingProfileResponse::to_json(
  self : SetChargingProfileResponse,
) -> Json {
  Json::object({
    "status": Json::string(charging_profile_status_name(self.status)),
  })
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ClearChargingProfileRequest {
  id : Int32?
  connector_id : Int32?
  charging_profile_purpose : ChargingProfilePurpose?
  stack_level : Int32?
}

///|
fn optional_profile_purpose(
  value : Json,
) -> ChargingProfilePurpose? raise ProtocolFailure {
  match optional_string(value, "chargingProfilePurpose") {
    None => None
    Some(text) => Some(parse_profile_purpose(text))
  }
}

///|
fn parse_clear_charging_profile(
  value : Json,
) -> ClearChargingProfileRequest raise ProtocolFailure {
  {
    id: optional_nonnegative_int(value, "id"),
    connector_id: optional_nonnegative_int(value, "connectorId"),
    charging_profile_purpose: optional_profile_purpose(value),
    stack_level: optional_nonnegative_int(value, "stackLevel"),
  }
}

///|
pub fn ClearChargingProfileRequest::from_json(
  value : Json,
) -> Result[ClearChargingProfileRequest, ProtocolError] {
  result_of(() => parse_clear_charging_profile(value))
}

///|
pub fn ClearChargingProfileRequest::to_json(
  self : ClearChargingProfileRequest,
) -> Json {
  let fields : Map[String, Json] = Map([])
  match self.id {
    Some(value) => fields.set("id", int_json(value))
    None => ()
  }
  match self.connector_id {
    Some(value) => fields.set("connectorId", int_json(value))
    None => ()
  }
  match self.charging_profile_purpose {
    Some(value) =>
      fields.set(
        "chargingProfilePurpose",
        Json::string(
          match value {
            ChargePointMaxProfile => "ChargePointMaxProfile"
            TxDefaultProfile => "TxDefaultProfile"
            TxProfile => "TxProfile"
          },
        ),
      )
    None => ()
  }
  match self.stack_level {
    Some(value) => fields.set("stackLevel", int_json(value))
    None => ()
  }
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum ClearChargingProfileStatus {
  Accepted
  Unknown
}

///|
fn parse_clear_profile_status(
  value : String,
) -> ClearChargingProfileStatus raise ProtocolFailure {
  match value {
    "Accepted" => Accepted
    "Unknown" => Unknown
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ClearChargingProfileResponse {
  status : ClearChargingProfileStatus
}

///|
fn parse_clear_profile_response(
  value : Json,
) -> ClearChargingProfileResponse raise ProtocolFailure {
  { status: parse_clear_profile_status(required_string(value, "status")), }
}

///|
pub fn ClearChargingProfileResponse::from_json(
  value : Json,
) -> Result[ClearChargingProfileResponse, ProtocolError] {
  result_of(() => parse_clear_profile_response(value))
}

///|
pub fn ClearChargingProfileResponse::to_json(
  self : ClearChargingProfileResponse,
) -> Json {
  Json::object({
    "status": Json::string(
      match self.status {
        Accepted => "Accepted"
        Unknown => "Unknown"
      },
    ),
  })
}
