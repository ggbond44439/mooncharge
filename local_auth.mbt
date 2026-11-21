///|
#derive(Eq, @debug.Debug)
pub(all) enum LocalListUpdateType {
  Differential
  Full
}

///|
fn parse_local_list_update_type(
  value : String,
) -> LocalListUpdateType raise ProtocolFailure {
  match value {
    "Differential" => Differential
    "Full" => Full
    _ => refuse(UnsupportedValue("updateType", value))
  }
}

///|
fn local_list_update_type_name(value : LocalListUpdateType) -> String {
  match value {
    Differential => "Differential"
    Full => "Full"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct LocalAuthorizationEntry {
  id_tag : String
  id_tag_info : IdTagInfo
}

///|
fn parse_local_authorization_entry(
  value : Json,
) -> LocalAuthorizationEntry raise ProtocolFailure {
  let id_tag = required_string(value, "idTag")
  if id_tag.is_empty() {
    refuse(InvalidField("idTag"))
  }
  {
    id_tag,
    id_tag_info: parse_id_tag_info(required_object(value, "idTagInfo")),
  }
}

///|
pub fn LocalAuthorizationEntry::from_json(
  value : Json,
) -> Result[LocalAuthorizationEntry, ProtocolError] {
  result_of(() => parse_local_authorization_entry(value))
}

///|
pub fn LocalAuthorizationEntry::to_json(self : LocalAuthorizationEntry) -> Json {
  Json::object({
    "idTag": Json::string(self.id_tag),
    "idTagInfo": self.id_tag_info.to_json(),
  })
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct SendLocalListRequest {
  list_version : Int32
  update_type : LocalListUpdateType
  local_authorization_list : Array[LocalAuthorizationEntry]
}

///|
fn parse_send_local_list(
  value : Json,
) -> SendLocalListRequest raise ProtocolFailure {
  let fields = match value {
    Json::Object(fields) => fields
    _ => refuse(InvalidPayload)
  }
  let entries = match fields.get("localAuthorizationList") {
    None | Some(Json::Null) => []
    Some(field) => {
      let items = match field {
        Json::Array(items) => items
        _ => refuse(InvalidField("localAuthorizationList"))
      }
      let values = []
      for item in items {
        values.push(parse_local_authorization_entry(item))
      }
      values
    }
  }
  {
    list_version: required_nonnegative_int(value, "listVersion"),
    update_type: parse_local_list_update_type(
      required_string(value, "updateType"),
    ),
    local_authorization_list: entries,
  }
}

///|
pub fn SendLocalListRequest::from_json(
  value : Json,
) -> Result[SendLocalListRequest, ProtocolError] {
  result_of(() => parse_send_local_list(value))
}

///|
pub fn SendLocalListRequest::to_json(self : SendLocalListRequest) -> Json {
  Json::object({
    "listVersion": int_json(self.list_version),
    "updateType": Json::string(local_list_update_type_name(self.update_type)),
    "localAuthorizationList": Json::array(
      self.local_authorization_list.map(fn(entry) { entry.to_json() }),
    ),
  })
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum LocalListUpdateStatus {
  Accepted
  Failed
  NotSupported
  VersionMismatch
}

///|
fn parse_local_list_update_status(
  value : String,
) -> LocalListUpdateStatus raise ProtocolFailure {
  match value {
    "Accepted" => Accepted
    "Failed" => Failed
    "NotSupported" => NotSupported
    "VersionMismatch" => VersionMismatch
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
fn local_list_update_status_name(value : LocalListUpdateStatus) -> String {
  match value {
    Accepted => "Accepted"
    Failed => "Failed"
    NotSupported => "NotSupported"
    VersionMismatch => "VersionMismatch"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct SendLocalListResponse {
  status : LocalListUpdateStatus
}

///|
fn parse_send_local_list_response(
  value : Json,
) -> SendLocalListResponse raise ProtocolFailure {
  { status: parse_local_list_update_status(required_string(value, "status")), }
}

///|
pub fn SendLocalListResponse::from_json(
  value : Json,
) -> Result[SendLocalListResponse, ProtocolError] {
  result_of(() => parse_send_local_list_response(value))
}

///|
pub fn SendLocalListResponse::to_json(self : SendLocalListResponse) -> Json {
  Json::object({
    "status": Json::string(local_list_update_status_name(self.status)),
  })
}

///|
#derive(Eq, @debug.Debug)
pub struct GetLocalListVersionRequest {
  marker : Unit
}

///|
pub fn GetLocalListVersionRequest::new() -> GetLocalListVersionRequest {
  { marker: (), }
}

///|
fn parse_get_local_list_version(
  value : Json,
) -> GetLocalListVersionRequest raise ProtocolFailure {
  ensure_empty_object(value)
  GetLocalListVersionRequest::new()
}

///|
pub fn GetLocalListVersionRequest::from_json(
  value : Json,
) -> Result[GetLocalListVersionRequest, ProtocolError] {
  result_of(() => parse_get_local_list_version(value))
}

///|
pub fn GetLocalListVersionRequest::to_json(
  self : GetLocalListVersionRequest,
) -> Json {
  ignore(self)
  empty_object()
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct GetLocalListVersionResponse {
  list_version : Int32
}

///|
fn parse_get_local_list_version_response(
  value : Json,
) -> GetLocalListVersionResponse raise ProtocolFailure {
  { list_version: required_nonnegative_int(value, "listVersion"), }
}

///|
pub fn GetLocalListVersionResponse::from_json(
  value : Json,
) -> Result[GetLocalListVersionResponse, ProtocolError] {
  result_of(() => parse_get_local_list_version_response(value))
}

///|
pub fn GetLocalListVersionResponse::to_json(
  self : GetLocalListVersionResponse,
) -> Json {
  Json::object({ "listVersion": int_json(self.list_version) })
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum LocalAuthorizationError {
  VersionMismatch(Int32, Int32)
  DuplicateIdTag(String)
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct LocalAuthorizationStore {
  mut version : Int32
  mut entries : Array[LocalAuthorizationEntry]
}

///|
pub fn LocalAuthorizationStore::new() -> LocalAuthorizationStore {
  { version: 0, entries: [], }
}

///|
pub fn LocalAuthorizationStore::list_version(
  self : LocalAuthorizationStore,
) -> Int32 {
  self.version
}

///|
pub fn LocalAuthorizationStore::lookup(
  self : LocalAuthorizationStore,
  id_tag : String,
) -> IdTagInfo? {
  for entry in self.entries {
    if entry.id_tag == id_tag {
      return Some(entry.id_tag_info)
    }
  }
  None
}

///|
pub fn LocalAuthorizationStore::remove(
  self : LocalAuthorizationStore,
  id_tag : String,
) -> Bool {
  let remaining : Array[LocalAuthorizationEntry] = []
  let mut removed = false
  for entry in self.entries {
    if entry.id_tag == id_tag {
      removed = true
    } else {
      remaining.push(entry)
    }
  }
  self.entries = remaining
  removed
}

///|
pub fn LocalAuthorizationStore::apply(
  self : LocalAuthorizationStore,
  request : SendLocalListRequest,
) -> Result[Unit, LocalAuthorizationError] {
  if request.list_version <= self.version {
    return Err(VersionMismatch(self.version, request.list_version))
  }
  let seen : Array[String] = []
  for entry in request.local_authorization_list {
    if seen.contains(entry.id_tag) {
      return Err(DuplicateIdTag(entry.id_tag))
    }
    seen.push(entry.id_tag)
  }
  match request.update_type {
    Full => self.entries = request.local_authorization_list
    Differential =>
      for entry in request.local_authorization_list {
        let mut replaced = false
        for index in 0..<self.entries.length() {
          if self.entries[index].id_tag == entry.id_tag {
            self.entries[index] = entry
            replaced = true
          }
        }
        if !replaced {
          self.entries.push(entry)
        }
      }
  }
  self.version = request.list_version
  Ok(())
}

///|
pub fn LocalAuthorizationStore::authorize(
  self : LocalAuthorizationStore,
  id_tag : String,
) -> IdTagInfo? {
  self.lookup(id_tag)
}
