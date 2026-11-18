///|
pub(all) enum ConfigurationStatus {
  Accepted
  Rejected
  RebootRequired
  NotSupported
} derive(Eq, @debug.Debug)

///|
fn parse_configuration_status(
  value : String,
) -> ConfigurationStatus raise ProtocolFailure {
  match value {
    "Accepted" => Accepted
    "Rejected" => Rejected
    "RebootRequired" => RebootRequired
    "NotSupported" => NotSupported
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
fn configuration_status_name(value : ConfigurationStatus) -> String {
  match value {
    Accepted => "Accepted"
    Rejected => "Rejected"
    RebootRequired => "RebootRequired"
    NotSupported => "NotSupported"
  }
}

///|
pub(all) struct ChangeConfigurationRequest {
  key : String
  value : String
} derive(Eq, @debug.Debug)

///|
fn parse_change_configuration(
  value : Json,
) -> ChangeConfigurationRequest raise ProtocolFailure {
  let key = required_string(value, "key")
  if key.is_empty() {
    refuse(InvalidField("key"))
  }
  { key, value: required_string(value, "value"), }
}

///|
pub fn ChangeConfigurationRequest::from_json(
  value : Json,
) -> Result[ChangeConfigurationRequest, ProtocolError] {
  result_of(() => parse_change_configuration(value))
}

///|
pub fn ChangeConfigurationRequest::to_json(
  self : ChangeConfigurationRequest,
) -> Json {
  Json::object({
    "key": Json::string(self.key),
    "value": Json::string(self.value),
  })
}

///|
pub(all) struct ChangeConfigurationResponse {
  status : ConfigurationStatus
} derive(Eq, @debug.Debug)

///|
fn parse_change_configuration_response(
  value : Json,
) -> ChangeConfigurationResponse raise ProtocolFailure {
  { status: parse_configuration_status(required_string(value, "status")), }
}

///|
pub fn ChangeConfigurationResponse::from_json(
  value : Json,
) -> Result[ChangeConfigurationResponse, ProtocolError] {
  result_of(() => parse_change_configuration_response(value))
}

///|
pub fn ChangeConfigurationResponse::to_json(
  self : ChangeConfigurationResponse,
) -> Json {
  Json::object({
    "status": Json::string(configuration_status_name(self.status)),
  })
}

///|
pub(all) struct GetConfigurationRequest {
  keys : Array[String]
} derive(Eq, @debug.Debug)

///|
fn string_array(
  field : Json,
  name : String,
) -> Array[String] raise ProtocolFailure {
  let items = match field {
    Json::Array(items) => items
    _ => refuse(InvalidField(name))
  }
  let values = []
  for item in items {
    match item {
      Json::String(value) if !value.is_empty() => values.push(value)
      _ => refuse(InvalidField(name))
    }
  }
  values
}

///|
fn parse_get_configuration(
  value : Json,
) -> GetConfigurationRequest raise ProtocolFailure {
  let fields = match value {
    Json::Object(fields) => fields
    _ => refuse(InvalidPayload)
  }
  {
    keys: match fields.get("key") {
      None | Some(Json::Null) => []
      Some(field) => string_array(field, "key")
    },
  }
}

///|
pub fn GetConfigurationRequest::from_json(
  value : Json,
) -> Result[GetConfigurationRequest, ProtocolError] {
  result_of(() => parse_get_configuration(value))
}

///|
pub fn GetConfigurationRequest::to_json(self : GetConfigurationRequest) -> Json {
  Json::object({
    "key": Json::array(self.keys.map(fn(value) { Json::string(value) })),
  })
}

///|
pub(all) struct ConfigurationKey {
  key : String
  is_readonly : Bool
  value : String?
} derive(Eq, @debug.Debug)

///|
fn parse_configuration_key(
  value : Json,
) -> ConfigurationKey raise ProtocolFailure {
  let key = required_string(value, "key")
  if key.is_empty() {
    refuse(InvalidField("key"))
  }
  let is_readonly = match object_field(value, "readonly") {
    Json::True => true
    Json::False => false
    _ => refuse(InvalidField("readonly"))
  }
  { key, is_readonly, value: optional_string(value, "value"), }
}

///|
pub fn ConfigurationKey::from_json(
  value : Json,
) -> Result[ConfigurationKey, ProtocolError] {
  result_of(() => parse_configuration_key(value))
}

///|
pub fn ConfigurationKey::to_json(self : ConfigurationKey) -> Json {
  let fields : Map[String, Json] = {
    "key": Json::string(self.key),
    "readonly": Json::boolean(self.is_readonly),
  }
  set_optional_string(fields, "value", self.value)
  Json::object(fields)
}

///|
pub(all) struct GetConfigurationResponse {
  configuration_key : Array[ConfigurationKey]
  unknown_key : Array[String]
} derive(Eq, @debug.Debug)

///|
fn parse_get_configuration_response(
  value : Json,
) -> GetConfigurationResponse raise ProtocolFailure {
  let fields = match value {
    Json::Object(fields) => fields
    _ => refuse(InvalidPayload)
  }
  let configuration_key = match fields.get("configurationKey") {
    None | Some(Json::Null) => []
    Some(field) => {
      let items = match field {
        Json::Array(items) => items
        _ => refuse(InvalidField("configurationKey"))
      }
      let values = []
      for item in items {
        values.push(parse_configuration_key(item))
      }
      values
    }
  }
  {
    configuration_key,
    unknown_key: match fields.get("unknownKey") {
      None | Some(Json::Null) => []
      Some(field) => string_array(field, "unknownKey")
    },
  }
}

///|
pub fn GetConfigurationResponse::from_json(
  value : Json,
) -> Result[GetConfigurationResponse, ProtocolError] {
  result_of(() => parse_get_configuration_response(value))
}

///|
pub fn GetConfigurationResponse::to_json(
  self : GetConfigurationResponse,
) -> Json {
  Json::object({
    "configurationKey": Json::array(
      self.configuration_key.map(fn(value) { value.to_json() }),
    ),
    "unknownKey": Json::array(
      self.unknown_key.map(fn(value) { Json::string(value) }),
    ),
  })
}
