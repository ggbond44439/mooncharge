///|
pub const SNAPSHOT_SCHEMA_VERSION : Int32 = 2

///|
#derive(Eq, @debug.Debug)
pub(all) enum SnapshotError {
  InvalidJson
  UnsupportedSchemaVersion(Int32)
  MissingField(String)
  InvalidField(String)
  DuplicateConnectorId(Int32)
  DuplicateTransactionId(Int32)
  DuplicateReservationId(Int32)
  ConnectorAlreadyReserved(Int32)
  DuplicateLocalIdTag(String)
  InconsistentStation(Array[StationConsistencyIssue])
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ChargePointSnapshot {
  station : ChargePointSession
  reservations : ReservationBook
  local_auth : LocalAuthorizationStore
  timed_profiles : Array[TimedChargingProfile]
}

///|
priv suberror SnapshotAbort {
  SnapshotAbort(SnapshotError)
}

///|
fn[T] snapshot_fail(error : SnapshotError) -> T raise SnapshotAbort {
  raise SnapshotAbort(error)
}

///|
fn snapshot_object(
  value : Json,
  name : String,
) -> Map[String, Json] raise SnapshotAbort {
  match value {
    Json::Object(fields) => fields
    _ => snapshot_fail(InvalidField(name))
  }
}

///|
fn snapshot_field(value : Json, name : String) -> Json raise SnapshotAbort {
  let fields = snapshot_object(value, name)
  match fields.get(name) {
    Some(field) => field
    None => snapshot_fail(MissingField(name))
  }
}

///|
fn snapshot_string(value : Json, name : String) -> String raise SnapshotAbort {
  match snapshot_field(value, name) {
    Json::String(text) => text
    _ => snapshot_fail(InvalidField(name))
  }
}

///|
fn snapshot_optional_string(
  value : Json,
  name : String,
) -> String? raise SnapshotAbort {
  let fields = snapshot_object(value, name)
  match fields.get(name) {
    None | Some(Json::Null) => None
    Some(Json::String(text)) => Some(text)
    Some(_) => snapshot_fail(InvalidField(name))
  }
}

///|
fn snapshot_array(
  value : Json,
  name : String,
) -> Array[Json] raise SnapshotAbort {
  match snapshot_field(value, name) {
    Json::Array(items) => items
    _ => snapshot_fail(InvalidField(name))
  }
}

///|
fn snapshot_int32(value : Json, name : String) -> Int32 raise SnapshotAbort {
  match snapshot_field(value, name) {
    Json::Number(number, ..) => {
      let int = number.to_int()
      if int >= 0 && int.to_double() == number {
        int
      } else {
        snapshot_fail(InvalidField(name))
      }
    }
    _ => snapshot_fail(InvalidField(name))
  }
}

///|
fn snapshot_optional_int32(
  value : Json,
  name : String,
) -> Int32? raise SnapshotAbort {
  let fields = snapshot_object(value, name)
  match fields.get(name) {
    None | Some(Json::Null) => None
    Some(Json::Number(number, ..)) => {
      let int = number.to_int()
      if int >= 0 && int.to_double() == number {
        Some(int)
      } else {
        snapshot_fail(InvalidField(name))
      }
    }
    Some(_) => snapshot_fail(InvalidField(name))
  }
}

///|
fn snapshot_int64_string(
  value : Json,
  name : String,
) -> Int64 raise SnapshotAbort {
  let text = snapshot_string(value, name)
  @string.parse_int64(text) catch {
    _ => snapshot_fail(InvalidField(name))
  }
}

///|
fn snapshot_optional_int64_string(
  value : Json,
  name : String,
) -> Int64? raise SnapshotAbort {
  match snapshot_optional_string(value, name) {
    None => None
    Some(text) =>
      Some(
        @string.parse_int64(text) catch {
          _ => snapshot_fail(InvalidField(name))
        },
      )
  }
}

///|
fn int64_string_json(value : Int64) -> Json {
  Json::string(value.to_string())
}

///|
fn transaction_to_json(value : ChargingTransaction) -> Json {
  let fields : Map[String, Json] = {
    "transactionId": int_json(value.transaction_id),
    "idTag": Json::string(value.id_tag),
    "meterStart": int_json(value.meter_start),
    "startTimestamp": Json::string(value.start_timestamp),
  }
  match value.meter_stop {
    Some(value) => fields.set("meterStop", int_json(value))
    None => ()
  }
  set_optional_string(fields, "stopTimestamp", value.stop_timestamp)
  match value.stop_reason {
    Some(value) =>
      fields.set("stopReason", Json::string(stop_reason_name(value)))
    None => ()
  }
  Json::object(fields)
}

///|
fn parse_stop_reason_snapshot(value : String) -> StopReason raise SnapshotAbort {
  stop_reason(value) catch {
    Failure(_) => snapshot_fail(InvalidField("stopReason"))
  }
}

///|
fn parse_transaction(value : Json) -> ChargingTransaction raise SnapshotAbort {
  {
    transaction_id: snapshot_int32(value, "transactionId"),
    id_tag: snapshot_string(value, "idTag"),
    meter_start: snapshot_int32(value, "meterStart"),
    start_timestamp: snapshot_string(value, "startTimestamp"),
    meter_stop: snapshot_optional_int32(value, "meterStop"),
    stop_timestamp: snapshot_optional_string(value, "stopTimestamp"),
    stop_reason: match snapshot_optional_string(value, "stopReason") {
      Some(reason) => Some(parse_stop_reason_snapshot(reason))
      None => None
    },
  }
}

///|
fn connector_to_json(value : ConnectorSession) -> Json {
  let fields : Map[String, Json] = {
    "connectorId": int_json(value.connector_id),
    "status": Json::string(value.status.name()),
  }
  match value.transaction {
    Some(transaction) =>
      fields.set("transaction", transaction_to_json(transaction))
    None => fields.set("transaction", Json::null())
  }
  Json::object(fields)
}

///|
fn parse_connector(value : Json) -> ConnectorSession raise SnapshotAbort {
  let status_text = snapshot_string(value, "status")
  let status = match ChargePointStatus::parse(status_text) {
    Some(status) => status
    None => snapshot_fail(InvalidField("status"))
  }
  let transaction = match
    snapshot_object(value, "connector").get("transaction") {
    None | Some(Json::Null) => None
    Some(transaction) => Some(parse_transaction(transaction))
  }
  { connector_id: snapshot_int32(value, "connectorId"), status, transaction, }
}

///|
fn station_to_json(value : ChargePointSession) -> Json {
  Json::object({
    "mode": Json::string(
      match value.station_mode {
        Operative => "Operative"
        Inoperative => "Inoperative"
      },
    ),
    "connectors": Json::array(
      value.connectors.map(fn(connector) { connector_to_json(connector) }),
    ),
  })
}

///|
fn parse_station(value : Json) -> ChargePointSession raise SnapshotAbort {
  let mode_text = snapshot_string(value, "mode")
  let mode = match mode_text {
    "Operative" => StationMode::Operative
    "Inoperative" => StationMode::Inoperative
    _ => snapshot_fail(InvalidField("mode"))
  }
  let connectors : Array[ConnectorSession] = []
  for item in snapshot_array(value, "connectors") {
    connectors.push(parse_connector(item))
  }
  { station_mode: mode, connectors, }
}

///|
fn reservation_to_json(value : Reservation) -> Json {
  let fields : Map[String, Json] = {
    "reservationId": int_json(value.reservation_id),
    "connectorId": int_json(value.connector_id),
    "idTag": Json::string(value.id_tag),
    "expiresAt": int64_string_json(value.expires_at),
  }
  set_optional_string(fields, "parentIdTag", value.parent_id_tag)
  Json::object(fields)
}

///|
fn parse_reservation(value : Json) -> Reservation raise SnapshotAbort {
  {
    reservation_id: snapshot_int32(value, "reservationId"),
    connector_id: snapshot_int32(value, "connectorId"),
    id_tag: snapshot_string(value, "idTag"),
    expires_at: snapshot_int64_string(value, "expiresAt"),
    parent_id_tag: snapshot_optional_string(value, "parentIdTag"),
  }
}

///|
fn local_auth_to_json(value : LocalAuthorizationStore) -> Json {
  Json::object({
    "version": int_json(value.version),
    "entries": Json::array(value.entries.map(fn(entry) { entry.to_json() })),
  })
}

///|
fn parse_local_auth(
  value : Json,
) -> LocalAuthorizationStore raise SnapshotAbort {
  let entries : Array[LocalAuthorizationEntry] = []
  for item in snapshot_array(value, "entries") {
    let entry = match LocalAuthorizationEntry::from_json(item) {
      Ok(entry) => entry
      Err(_) => snapshot_fail(InvalidField("entries"))
    }
    entries.push(entry)
  }
  { version: snapshot_int32(value, "version"), entries, }
}

///|
fn validity_to_json(value : EpochInterval) -> Json {
  let fields : Map[String, Json] = { "start": int64_string_json(value.start) }
  match value.end {
    Some(end) => fields.set("end", int64_string_json(end))
    None => fields.set("end", Json::null())
  }
  Json::object(fields)
}

///|
fn parse_validity(value : Json) -> EpochInterval raise SnapshotAbort {
  let interval = {
    start: snapshot_int64_string(value, "start"),
    end: snapshot_optional_int64_string(value, "end"),
  }
  match EpochInterval::new(interval.start, interval.end) {
    Ok(value) => value
    Err(_) => snapshot_fail(InvalidField("validity"))
  }
}

///|
fn timed_profile_to_json(value : TimedChargingProfile) -> Json {
  let fields : Map[String, Json] = {
    "profile": value.profile.to_json(),
    "scheduleStartEpoch": int64_string_json(value.schedule_start_epoch),
  }
  match value.validity {
    Some(validity) => fields.set("validity", validity_to_json(validity))
    None => fields.set("validity", Json::null())
  }
  match value.transaction_start_epoch {
    Some(epoch) => fields.set("transactionStartEpoch", int64_string_json(epoch))
    None => fields.set("transactionStartEpoch", Json::null())
  }
  Json::object(fields)
}

///|
fn parse_timed_profile(
  value : Json,
) -> TimedChargingProfile raise SnapshotAbort {
  let profile_json = snapshot_field(value, "profile")
  let profile = match ChargingProfile::from_json(profile_json) {
    Ok(profile) => profile
    Err(_) => snapshot_fail(InvalidField("profile"))
  }
  let validity = match snapshot_object(value, "timedProfile").get("validity") {
    None | Some(Json::Null) => None
    Some(validity) => Some(parse_validity(validity))
  }
  {
    profile,
    validity,
    schedule_start_epoch: snapshot_int64_string(value, "scheduleStartEpoch"),
    transaction_start_epoch: snapshot_optional_int64_string(
      value, "transactionStartEpoch",
    ),
  }
}

///|
fn validate_snapshot(
  value : ChargePointSnapshot,
) -> Result[Unit, SnapshotError] {
  let station_issues = value.station.consistency_issues()
  if !station_issues.is_empty() {
    return Err(InconsistentStation(station_issues))
  }
  let connector_ids : Array[Int32] = []
  let transaction_ids : Array[Int32] = []
  for connector in value.station.connectors {
    if connector_ids.contains(connector.connector_id) {
      return Err(DuplicateConnectorId(connector.connector_id))
    }
    connector_ids.push(connector.connector_id)
    match connector.transaction {
      Some(transaction) =>
        if transaction_ids.contains(transaction.transaction_id) {
          return Err(DuplicateTransactionId(transaction.transaction_id))
        } else {
          transaction_ids.push(transaction.transaction_id)
        }
      None => ()
    }
  }
  let reservation_ids : Array[Int32] = []
  let reserved_connectors : Array[Int32] = []
  for reservation in value.reservations.reservations {
    if reservation_ids.contains(reservation.reservation_id) {
      return Err(DuplicateReservationId(reservation.reservation_id))
    }
    if reserved_connectors.contains(reservation.connector_id) {
      return Err(ConnectorAlreadyReserved(reservation.connector_id))
    }
    reservation_ids.push(reservation.reservation_id)
    reserved_connectors.push(reservation.connector_id)
  }
  let local_tags : Array[String] = []
  for entry in value.local_auth.entries {
    if local_tags.contains(entry.id_tag) {
      return Err(DuplicateLocalIdTag(entry.id_tag))
    }
    local_tags.push(entry.id_tag)
  }
  Ok(())
}

///|
pub fn ChargePointSnapshot::new(
  station : ChargePointSession,
  reservations : ReservationBook,
  local_auth : LocalAuthorizationStore,
  timed_profiles : Array[TimedChargingProfile],
) -> Result[ChargePointSnapshot, SnapshotError] {
  let value = { station, reservations, local_auth, timed_profiles, }
  match validate_snapshot(value) {
    Ok(_) => Ok(value)
    Err(error) => Err(error)
  }
}

///|
pub fn ChargePointSnapshot::to_json(self : ChargePointSnapshot) -> Json {
  Json::object({
    "schemaVersion": Json::number(
      SNAPSHOT_SCHEMA_VERSION.to_double(),
      repr=SNAPSHOT_SCHEMA_VERSION.to_string(),
    ),
    "station": station_to_json(self.station),
    "reservations": Json::array(
      self.reservations.reservations.map(fn(reservation) {
        reservation_to_json(reservation)
      }),
    ),
    "localAuth": local_auth_to_json(self.local_auth),
    "timedProfiles": Json::array(
      self.timed_profiles.map(fn(profile) { timed_profile_to_json(profile) }),
    ),
  })
}

///|
pub fn ChargePointSnapshot::to_string(self : ChargePointSnapshot) -> String {
  self.to_json().stringify()
}

///|
fn migrate_v1(value : Json) -> ChargePointSnapshot raise SnapshotAbort {
  let items = snapshot_array(value, "connectors")
  let connector_ids : Array[Int32] = []
  let statuses : Array[ChargePointStatus] = []
  for item in items {
    connector_ids.push(snapshot_int32(item, "connectorId"))
    let status_text = snapshot_string(item, "status")
    let status = match ChargePointStatus::parse(status_text) {
      Some(status) => status
      None => snapshot_fail(InvalidField("status"))
    }
    statuses.push(status)
  }
  let station = match ChargePointSession::new(connector_ids) {
    Ok(station) => station
    Err(_) => snapshot_fail(InvalidField("connectors"))
  }
  for index in 0..<statuses.length() {
    station.connectors[index] = station.connectors[index].apply_status(
      statuses[index],
    )
  }
  {
    station,
    reservations: ReservationBook::new(),
    local_auth: LocalAuthorizationStore::new(),
    timed_profiles: [],
  }
}

///|
fn parse_snapshot(value : Json) -> ChargePointSnapshot raise SnapshotAbort {
  let fields = snapshot_object(value, "snapshot")
  let version = match fields.get("schemaVersion") {
    Some(field) =>
      match field {
        Json::Number(number, ..) => number.to_int()
        _ => snapshot_fail(InvalidField("schemaVersion"))
      }
    None =>
      match fields.get("version") {
        Some(field) =>
          match field {
            Json::Number(number, ..) => number.to_int()
            _ => snapshot_fail(InvalidField("version"))
          }
        None => 1
      }
  }
  if version == 1 {
    return migrate_v1(value)
  }
  if version != SNAPSHOT_SCHEMA_VERSION {
    return snapshot_fail(UnsupportedSchemaVersion(version))
  }
  let reservations = ReservationBook::new()
  for item in snapshot_array(value, "reservations") {
    reservations.reservations.push(parse_reservation(item))
  }
  let timed_profiles : Array[TimedChargingProfile] = []
  for item in snapshot_array(value, "timedProfiles") {
    timed_profiles.push(parse_timed_profile(item))
  }
  {
    station: parse_station(snapshot_field(value, "station")),
    reservations,
    local_auth: parse_local_auth(snapshot_field(value, "localAuth")),
    timed_profiles,
  }
}

///|
pub fn load_snapshot(
  text : String,
) -> Result[ChargePointSnapshot, SnapshotError] {
  let value = @json.parse(
    text,
    max_nesting_depth=64,
    reject_duplicate_keys=true,
    preserve_number_repr=true,
  ) catch {
    _ => return Err(InvalidJson)
  }
  let snapshot = parse_snapshot(value) catch {
    SnapshotAbort(error) => return Err(error)
  }
  match validate_snapshot(snapshot) {
    Ok(_) => Ok(snapshot)
    Err(error) => Err(error)
  }
}

///|
pub fn save_snapshot(
  snapshot : ChargePointSnapshot,
) -> Result[String, SnapshotError] {
  match validate_snapshot(snapshot) {
    Ok(_) => Ok(snapshot.to_string())
    Err(error) => Err(error)
  }
}
