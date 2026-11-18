///|
/// Internal typed parsing failure used to keep payload codec code linear.
pub(all) suberror ProtocolFailure {
  Failure(ProtocolError)
}

///|
fn[T] result_of(
  parse : () -> T raise ProtocolFailure,
) -> Result[T, ProtocolError] {
  Ok(parse()) catch {
    Failure(error) => Err(error)
  }
}

///|
fn[T] refuse(error : ProtocolError) -> T raise ProtocolFailure {
  raise Failure(error)
}

///|
fn object_field(value : Json, name : String) -> Json raise ProtocolFailure {
  let fields = match value {
    Json::Object(fields) => fields
    _ => refuse(InvalidPayload)
  }
  match fields.get(name) {
    Some(field) => field
    None => refuse(MissingField(name))
  }
}

///|
fn required_string(value : Json, name : String) -> String raise ProtocolFailure {
  match object_field(value, name) {
    Json::String(text) => text
    _ => refuse(InvalidField(name))
  }
}

///|
fn optional_string(
  value : Json,
  name : String,
) -> String? raise ProtocolFailure {
  let fields = match value {
    Json::Object(fields) => fields
    _ => refuse(InvalidPayload)
  }
  match fields.get(name) {
    None | Some(Json::Null) => None
    Some(Json::String(text)) => Some(text)
    Some(_) => refuse(InvalidField(name))
  }
}

///|
fn required_array(
  value : Json,
  name : String,
) -> Array[Json] raise ProtocolFailure {
  match object_field(value, name) {
    Json::Array(items) => items
    _ => refuse(InvalidField(name))
  }
}

///|
fn required_object(value : Json, name : String) -> Json raise ProtocolFailure {
  let field = object_field(value, name)
  match field {
    Json::Object(_) => field
    _ => refuse(InvalidField(name))
  }
}

///|
fn json_int(field : Json, name : String) -> Int32 raise ProtocolFailure {
  match field {
    Json::Number(number, ..) => {
      let int = number.to_int()
      if int >= 0 && int.to_double() == number {
        int
      } else {
        refuse(InvalidField(name))
      }
    }
    _ => refuse(InvalidField(name))
  }
}

///|
fn required_nonnegative_int(
  value : Json,
  name : String,
) -> Int32 raise ProtocolFailure {
  json_int(object_field(value, name), name)
}

///|
fn optional_nonnegative_int(
  value : Json,
  name : String,
) -> Int32? raise ProtocolFailure {
  let fields = match value {
    Json::Object(fields) => fields
    _ => refuse(InvalidPayload)
  }
  match fields.get(name) {
    None | Some(Json::Null) => None
    Some(field) => Some(json_int(field, name))
  }
}

///|
fn int_json(value : Int32) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn set_optional_string(
  fields : Map[String, Json],
  name : String,
  value : String?,
) -> Unit {
  match value {
    Some(value) => fields.set(name, Json::string(value))
    None => ()
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum RegistrationStatus {
  Accepted
  Pending
  Rejected
}

///|
fn registration_status(
  value : String,
) -> RegistrationStatus raise ProtocolFailure {
  match value {
    "Accepted" => Accepted
    "Pending" => Pending
    "Rejected" => Rejected
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
fn registration_status_name(value : RegistrationStatus) -> String {
  match value {
    Accepted => "Accepted"
    Pending => "Pending"
    Rejected => "Rejected"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum AuthorizationStatus {
  Accepted
  Blocked
  Expired
  Invalid
  ConcurrentTx
}

///|
fn authorization_status(
  field : String,
  value : String,
) -> AuthorizationStatus raise ProtocolFailure {
  match value {
    "Accepted" => Accepted
    "Blocked" => Blocked
    "Expired" => Expired
    "Invalid" => Invalid
    "ConcurrentTx" => ConcurrentTx
    _ => refuse(UnsupportedValue(field, value))
  }
}

///|
fn authorization_status_name(value : AuthorizationStatus) -> String {
  match value {
    Accepted => "Accepted"
    Blocked => "Blocked"
    Expired => "Expired"
    Invalid => "Invalid"
    ConcurrentTx => "ConcurrentTx"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum ChargePointStatus {
  Available
  Preparing
  Charging
  SuspendedEV
  SuspendedEVSE
  Finishing
  Reserved
  Unavailable
  Faulted
}

///|
pub fn ChargePointStatus::parse(value : String) -> ChargePointStatus? {
  match value {
    "Available" => Some(Available)
    "Preparing" => Some(Preparing)
    "Charging" => Some(Charging)
    "SuspendedEV" => Some(SuspendedEV)
    "SuspendedEVSE" => Some(SuspendedEVSE)
    "Finishing" => Some(Finishing)
    "Reserved" => Some(Reserved)
    "Unavailable" => Some(Unavailable)
    "Faulted" => Some(Faulted)
    _ => None
  }
}

///|
pub fn ChargePointStatus::name(self : ChargePointStatus) -> String {
  match self {
    Available => "Available"
    Preparing => "Preparing"
    Charging => "Charging"
    SuspendedEV => "SuspendedEV"
    SuspendedEVSE => "SuspendedEVSE"
    Finishing => "Finishing"
    Reserved => "Reserved"
    Unavailable => "Unavailable"
    Faulted => "Faulted"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum ChargePointErrorCode {
  NoError
  ConnectorLockFailure
  EVCommunicationError
  GroundFailure
  HighTemperature
  InternalError
  LocalListConflict
  OtherError
  OverCurrentFailure
  PowerMeterFailure
  PowerSwitchFailure
  ReaderFailure
  ResetFailure
  UnderVoltage
  WeakSignal
}

///|
fn error_code(value : String) -> ChargePointErrorCode raise ProtocolFailure {
  match value {
    "NoError" => NoError
    "ConnectorLockFailure" => ConnectorLockFailure
    "EVCommunicationError" => EVCommunicationError
    "GroundFailure" => GroundFailure
    "HighTemperature" => HighTemperature
    "InternalError" => InternalError
    "LocalListConflict" => LocalListConflict
    "OtherError" => OtherError
    "OverCurrentFailure" => OverCurrentFailure
    "PowerMeterFailure" => PowerMeterFailure
    "PowerSwitchFailure" => PowerSwitchFailure
    "ReaderFailure" => ReaderFailure
    "ResetFailure" => ResetFailure
    "UnderVoltage" => UnderVoltage
    "WeakSignal" => WeakSignal
    _ => refuse(UnsupportedValue("errorCode", value))
  }
}

///|
fn error_code_name(value : ChargePointErrorCode) -> String {
  match value {
    NoError => "NoError"
    ConnectorLockFailure => "ConnectorLockFailure"
    EVCommunicationError => "EVCommunicationError"
    GroundFailure => "GroundFailure"
    HighTemperature => "HighTemperature"
    InternalError => "InternalError"
    LocalListConflict => "LocalListConflict"
    OtherError => "OtherError"
    OverCurrentFailure => "OverCurrentFailure"
    PowerMeterFailure => "PowerMeterFailure"
    PowerSwitchFailure => "PowerSwitchFailure"
    ReaderFailure => "ReaderFailure"
    ResetFailure => "ResetFailure"
    UnderVoltage => "UnderVoltage"
    WeakSignal => "WeakSignal"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum StopReason {
  EmergencyStop
  EVDisconnected
  HardReset
  Local
  Other
  PowerLoss
  Reboot
  Remote
  SoftReset
  UnlockCommand
  DeAuthorized
}

///|
fn stop_reason(value : String) -> StopReason raise ProtocolFailure {
  match value {
    "EmergencyStop" => EmergencyStop
    "EVDisconnected" => EVDisconnected
    "HardReset" => HardReset
    "Local" => Local
    "Other" => Other
    "PowerLoss" => PowerLoss
    "Reboot" => Reboot
    "Remote" => Remote
    "SoftReset" => SoftReset
    "UnlockCommand" => UnlockCommand
    "DeAuthorized" => DeAuthorized
    _ => refuse(UnsupportedValue("reason", value))
  }
}

///|
fn stop_reason_name(value : StopReason) -> String {
  match value {
    EmergencyStop => "EmergencyStop"
    EVDisconnected => "EVDisconnected"
    HardReset => "HardReset"
    Local => "Local"
    Other => "Other"
    PowerLoss => "PowerLoss"
    Reboot => "Reboot"
    Remote => "Remote"
    SoftReset => "SoftReset"
    UnlockCommand => "UnlockCommand"
    DeAuthorized => "DeAuthorized"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct IdTagInfo {
  status : AuthorizationStatus
  expiry_date : String?
  parent_id_tag : String?
}

///|
fn parse_id_tag_info(value : Json) -> IdTagInfo raise ProtocolFailure {
  {
    status: authorization_status("status", required_string(value, "status")),
    expiry_date: optional_string(value, "expiryDate"),
    parent_id_tag: optional_string(value, "parentIdTag"),
  }
}

///|
pub fn IdTagInfo::from_json(value : Json) -> Result[IdTagInfo, ProtocolError] {
  result_of(() => parse_id_tag_info(value))
}

///|
pub fn IdTagInfo::to_json(self : IdTagInfo) -> Json {
  let fields : Map[String, Json] = {
    "status": Json::string(authorization_status_name(self.status)),
  }
  set_optional_string(fields, "expiryDate", self.expiry_date)
  set_optional_string(fields, "parentIdTag", self.parent_id_tag)
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct BootNotificationRequest {
  charge_point_vendor : String
  charge_point_model : String
  charge_point_serial_number : String?
  charge_point_firmware_version : String?
  meter_type : String?
  meter_serial_number : String?
  iccid : String?
  imsi : String?
}

///|
fn parse_boot_notification_request(
  value : Json,
) -> BootNotificationRequest raise ProtocolFailure {
  {
    charge_point_vendor: required_string(value, "chargePointVendor"),
    charge_point_model: required_string(value, "chargePointModel"),
    charge_point_serial_number: optional_string(
      value, "chargePointSerialNumber",
    ),
    charge_point_firmware_version: optional_string(
      value, "chargePointFirmwareVersion",
    ),
    meter_type: optional_string(value, "meterType"),
    meter_serial_number: optional_string(value, "meterSerialNumber"),
    iccid: optional_string(value, "iccid"),
    imsi: optional_string(value, "imsi"),
  }
}

///|
pub fn BootNotificationRequest::from_json(
  value : Json,
) -> Result[BootNotificationRequest, ProtocolError] {
  result_of(() => parse_boot_notification_request(value))
}

///|
pub fn BootNotificationRequest::to_json(self : BootNotificationRequest) -> Json {
  let fields : Map[String, Json] = {
    "chargePointVendor": Json::string(self.charge_point_vendor),
    "chargePointModel": Json::string(self.charge_point_model),
  }
  set_optional_string(
    fields,
    "chargePointSerialNumber",
    self.charge_point_serial_number,
  )
  set_optional_string(
    fields,
    "chargePointFirmwareVersion",
    self.charge_point_firmware_version,
  )
  set_optional_string(fields, "meterType", self.meter_type)
  set_optional_string(fields, "meterSerialNumber", self.meter_serial_number)
  set_optional_string(fields, "iccid", self.iccid)
  set_optional_string(fields, "imsi", self.imsi)
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct BootNotificationResponse {
  status : RegistrationStatus
  current_time : String
  heartbeat_interval : Int32
}

///|
fn parse_boot_notification_response(
  value : Json,
) -> BootNotificationResponse raise ProtocolFailure {
  {
    status: registration_status(required_string(value, "status")),
    current_time: required_string(value, "currentTime"),
    heartbeat_interval: required_nonnegative_int(value, "heartbeatInterval"),
  }
}

///|
pub fn BootNotificationResponse::from_json(
  value : Json,
) -> Result[BootNotificationResponse, ProtocolError] {
  result_of(() => parse_boot_notification_response(value))
}

///|
pub fn BootNotificationResponse::to_json(
  self : BootNotificationResponse,
) -> Json {
  Json::object({
    "status": Json::string(registration_status_name(self.status)),
    "currentTime": Json::string(self.current_time),
    "heartbeatInterval": int_json(self.heartbeat_interval),
  })
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct HeartbeatResponse {
  current_time : String
}

///|
fn parse_heartbeat_response(
  value : Json,
) -> HeartbeatResponse raise ProtocolFailure {
  { current_time: required_string(value, "currentTime"), }
}

///|
pub fn HeartbeatResponse::from_json(
  value : Json,
) -> Result[HeartbeatResponse, ProtocolError] {
  result_of(() => parse_heartbeat_response(value))
}

///|
pub fn HeartbeatResponse::to_json(self : HeartbeatResponse) -> Json {
  Json::object({ "currentTime": Json::string(self.current_time) })
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct StatusNotificationRequest {
  connector_id : Int32
  error_code : ChargePointErrorCode
  status : ChargePointStatus
  timestamp : String?
  info : String?
  vendor_id : String?
  vendor_error_code : String?
}

///|
fn parse_status_notification_request(
  value : Json,
) -> StatusNotificationRequest raise ProtocolFailure {
  let status_text = required_string(value, "status")
  let status = match ChargePointStatus::parse(status_text) {
    Some(status) => status
    None => refuse(UnsupportedValue("status", status_text))
  }
  {
    connector_id: required_nonnegative_int(value, "connectorId"),
    error_code: error_code(required_string(value, "errorCode")),
    status,
    timestamp: optional_string(value, "timestamp"),
    info: optional_string(value, "info"),
    vendor_id: optional_string(value, "vendorId"),
    vendor_error_code: optional_string(value, "vendorErrorCode"),
  }
}

///|
pub fn StatusNotificationRequest::from_json(
  value : Json,
) -> Result[StatusNotificationRequest, ProtocolError] {
  result_of(() => parse_status_notification_request(value))
}

///|
pub fn StatusNotificationRequest::to_json(
  self : StatusNotificationRequest,
) -> Json {
  let fields : Map[String, Json] = {
    "connectorId": int_json(self.connector_id),
    "errorCode": Json::string(error_code_name(self.error_code)),
    "status": Json::string(self.status.name()),
  }
  set_optional_string(fields, "timestamp", self.timestamp)
  set_optional_string(fields, "info", self.info)
  set_optional_string(fields, "vendorId", self.vendor_id)
  set_optional_string(fields, "vendorErrorCode", self.vendor_error_code)
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct AuthorizeRequest {
  id_tag : String
}

///|
fn parse_authorize_request(
  value : Json,
) -> AuthorizeRequest raise ProtocolFailure {
  let id_tag = required_string(value, "idTag")
  if id_tag.is_empty() {
    refuse(InvalidField("idTag"))
  }
  { id_tag, }
}

///|
pub fn AuthorizeRequest::from_json(
  value : Json,
) -> Result[AuthorizeRequest, ProtocolError] {
  result_of(() => parse_authorize_request(value))
}

///|
pub fn AuthorizeRequest::to_json(self : AuthorizeRequest) -> Json {
  Json::object({ "idTag": Json::string(self.id_tag) })
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct AuthorizeResponse {
  id_tag_info : IdTagInfo
}

///|
fn parse_authorize_response(
  value : Json,
) -> AuthorizeResponse raise ProtocolFailure {
  { id_tag_info: parse_id_tag_info(required_object(value, "idTagInfo")), }
}

///|
pub fn AuthorizeResponse::from_json(
  value : Json,
) -> Result[AuthorizeResponse, ProtocolError] {
  result_of(() => parse_authorize_response(value))
}

///|
pub fn AuthorizeResponse::to_json(self : AuthorizeResponse) -> Json {
  Json::object({ "idTagInfo": self.id_tag_info.to_json() })
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct StartTransactionRequest {
  connector_id : Int32
  id_tag : String
  meter_start : Int32
  reservation_id : Int32?
  timestamp : String
}

///|
fn parse_start_transaction_request(
  value : Json,
) -> StartTransactionRequest raise ProtocolFailure {
  let id_tag = required_string(value, "idTag")
  if id_tag.is_empty() {
    refuse(InvalidField("idTag"))
  }
  {
    connector_id: required_nonnegative_int(value, "connectorId"),
    id_tag,
    meter_start: required_nonnegative_int(value, "meterStart"),
    reservation_id: optional_nonnegative_int(value, "reservationId"),
    timestamp: required_string(value, "timestamp"),
  }
}

///|
pub fn StartTransactionRequest::from_json(
  value : Json,
) -> Result[StartTransactionRequest, ProtocolError] {
  result_of(() => parse_start_transaction_request(value))
}

///|
pub fn StartTransactionRequest::to_json(self : StartTransactionRequest) -> Json {
  let fields : Map[String, Json] = {
    "connectorId": int_json(self.connector_id),
    "idTag": Json::string(self.id_tag),
    "meterStart": int_json(self.meter_start),
    "timestamp": Json::string(self.timestamp),
  }
  match self.reservation_id {
    Some(value) => fields.set("reservationId", int_json(value))
    None => ()
  }
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct StartTransactionResponse {
  transaction_id : Int32
  id_tag_info : IdTagInfo
}

///|
fn parse_start_transaction_response(
  value : Json,
) -> StartTransactionResponse raise ProtocolFailure {
  {
    transaction_id: required_nonnegative_int(value, "transactionId"),
    id_tag_info: parse_id_tag_info(required_object(value, "idTagInfo")),
  }
}

///|
pub fn StartTransactionResponse::from_json(
  value : Json,
) -> Result[StartTransactionResponse, ProtocolError] {
  result_of(() => parse_start_transaction_response(value))
}

///|
pub fn StartTransactionResponse::to_json(
  self : StartTransactionResponse,
) -> Json {
  Json::object({
    "transactionId": int_json(self.transaction_id),
    "idTagInfo": self.id_tag_info.to_json(),
  })
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct StopTransactionRequest {
  transaction_id : Int32
  meter_stop : Int32
  timestamp : String
  reason : StopReason?
  id_tag : String?
}

///|
fn parse_stop_transaction_request(
  value : Json,
) -> StopTransactionRequest raise ProtocolFailure {
  let reason = match optional_string(value, "reason") {
    None => None
    Some(text) => Some(stop_reason(text))
  }
  {
    transaction_id: required_nonnegative_int(value, "transactionId"),
    meter_stop: required_nonnegative_int(value, "meterStop"),
    timestamp: required_string(value, "timestamp"),
    reason,
    id_tag: optional_string(value, "idTag"),
  }
}

///|
pub fn StopTransactionRequest::from_json(
  value : Json,
) -> Result[StopTransactionRequest, ProtocolError] {
  result_of(() => parse_stop_transaction_request(value))
}

///|
pub fn StopTransactionRequest::to_json(self : StopTransactionRequest) -> Json {
  let fields : Map[String, Json] = {
    "transactionId": int_json(self.transaction_id),
    "meterStop": int_json(self.meter_stop),
    "timestamp": Json::string(self.timestamp),
  }
  match self.reason {
    Some(reason) => fields.set("reason", Json::string(stop_reason_name(reason)))
    None => ()
  }
  set_optional_string(fields, "idTag", self.id_tag)
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct SampledValue {
  value : String
  context : String?
  format : String?
  measurand : String?
  phase : String?
  location : String?
  unit : String?
}

///|
fn parse_sampled_value(value : Json) -> SampledValue raise ProtocolFailure {
  let sampled = required_string(value, "value")
  if sampled.is_empty() {
    refuse(InvalidField("value"))
  }
  {
    value: sampled,
    context: optional_string(value, "context"),
    format: optional_string(value, "format"),
    measurand: optional_string(value, "measurand"),
    phase: optional_string(value, "phase"),
    location: optional_string(value, "location"),
    unit: optional_string(value, "unit"),
  }
}

///|
pub fn SampledValue::from_json(
  value : Json,
) -> Result[SampledValue, ProtocolError] {
  result_of(() => parse_sampled_value(value))
}

///|
pub fn SampledValue::to_json(self : SampledValue) -> Json {
  let fields : Map[String, Json] = { "value": Json::string(self.value) }
  set_optional_string(fields, "context", self.context)
  set_optional_string(fields, "format", self.format)
  set_optional_string(fields, "measurand", self.measurand)
  set_optional_string(fields, "phase", self.phase)
  set_optional_string(fields, "location", self.location)
  set_optional_string(fields, "unit", self.unit)
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct MeterValue {
  timestamp : String
  sampled_value : Array[SampledValue]
}

///|
fn parse_meter_value(value : Json) -> MeterValue raise ProtocolFailure {
  let items = required_array(value, "sampledValue")
  if items.is_empty() {
    refuse(InvalidField("sampledValue"))
  }
  let sampled_value = []
  for item in items {
    sampled_value.push(parse_sampled_value(item))
  }
  { timestamp: required_string(value, "timestamp"), sampled_value, }
}

///|
pub fn MeterValue::from_json(value : Json) -> Result[MeterValue, ProtocolError] {
  result_of(() => parse_meter_value(value))
}

///|
pub fn MeterValue::to_json(self : MeterValue) -> Json {
  Json::object({
    "timestamp": Json::string(self.timestamp),
    "sampledValue": Json::array(
      self.sampled_value.map(fn(value) { value.to_json() }),
    ),
  })
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct MeterValuesRequest {
  connector_id : Int32
  transaction_id : Int32?
  meter_value : Array[MeterValue]
}

///|
fn parse_meter_values_request(
  value : Json,
) -> MeterValuesRequest raise ProtocolFailure {
  let items = required_array(value, "meterValue")
  if items.is_empty() {
    refuse(InvalidField("meterValue"))
  }
  let meter_value = []
  for item in items {
    meter_value.push(parse_meter_value(item))
  }
  {
    connector_id: required_nonnegative_int(value, "connectorId"),
    transaction_id: optional_nonnegative_int(value, "transactionId"),
    meter_value,
  }
}

///|
pub fn MeterValuesRequest::from_json(
  value : Json,
) -> Result[MeterValuesRequest, ProtocolError] {
  result_of(() => parse_meter_values_request(value))
}

///|
pub fn MeterValuesRequest::to_json(self : MeterValuesRequest) -> Json {
  let fields : Map[String, Json] = {
    "connectorId": int_json(self.connector_id),
    "meterValue": Json::array(
      self.meter_value.map(fn(value) { value.to_json() }),
    ),
  }
  match self.transaction_id {
    Some(value) => fields.set("transactionId", int_json(value))
    None => ()
  }
  Json::object(fields)
}
