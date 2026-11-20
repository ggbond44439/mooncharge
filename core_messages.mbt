///|
fn ensure_empty_object(value : Json) -> Unit raise ProtocolFailure {
  match value {
    Json::Object(fields) => if !fields.is_empty() { refuse(InvalidPayload) }
    _ => refuse(InvalidPayload)
  }
}

///|
fn empty_object() -> Json {
  Json::object(Map([]))
}

///|
#derive(Eq, @debug.Debug)
pub struct HeartbeatRequest {
  marker : Unit
}

///|
pub fn HeartbeatRequest::new() -> HeartbeatRequest {
  { marker: (), }
}

///|
fn parse_heartbeat_request(
  value : Json,
) -> HeartbeatRequest raise ProtocolFailure {
  ensure_empty_object(value)
  HeartbeatRequest::new()
}

///|
pub fn HeartbeatRequest::from_json(
  value : Json,
) -> Result[HeartbeatRequest, ProtocolError] {
  result_of(() => parse_heartbeat_request(value))
}

///|
pub fn HeartbeatRequest::to_json(self : HeartbeatRequest) -> Json {
  ignore(self)
  empty_object()
}

///|
#derive(Eq, @debug.Debug)
pub struct MeterValuesResponse {
  marker : Unit
}

///|
pub fn MeterValuesResponse::new() -> MeterValuesResponse {
  { marker: (), }
}

///|
fn parse_meter_values_response(
  value : Json,
) -> MeterValuesResponse raise ProtocolFailure {
  ensure_empty_object(value)
  MeterValuesResponse::new()
}

///|
pub fn MeterValuesResponse::from_json(
  value : Json,
) -> Result[MeterValuesResponse, ProtocolError] {
  result_of(() => parse_meter_values_response(value))
}

///|
pub fn MeterValuesResponse::to_json(self : MeterValuesResponse) -> Json {
  ignore(self)
  empty_object()
}

///|
#derive(Eq, @debug.Debug)
pub struct StatusNotificationResponse {
  marker : Unit
}

///|
pub fn StatusNotificationResponse::new() -> StatusNotificationResponse {
  { marker: (), }
}

///|
fn parse_status_notification_response(
  value : Json,
) -> StatusNotificationResponse raise ProtocolFailure {
  ensure_empty_object(value)
  StatusNotificationResponse::new()
}

///|
pub fn StatusNotificationResponse::from_json(
  value : Json,
) -> Result[StatusNotificationResponse, ProtocolError] {
  result_of(() => parse_status_notification_response(value))
}

///|
pub fn StatusNotificationResponse::to_json(
  self : StatusNotificationResponse,
) -> Json {
  ignore(self)
  empty_object()
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct StopTransactionResponse {
  id_tag_info : IdTagInfo?
}

///|
fn parse_stop_transaction_response(
  value : Json,
) -> StopTransactionResponse raise ProtocolFailure {
  let fields = match value {
    Json::Object(fields) => fields
    _ => refuse(InvalidPayload)
  }
  {
    id_tag_info: match fields.get("idTagInfo") {
      None | Some(Json::Null) => None
      Some(field) => Some(parse_id_tag_info(field))
    },
  }
}

///|
pub fn StopTransactionResponse::from_json(
  value : Json,
) -> Result[StopTransactionResponse, ProtocolError] {
  result_of(() => parse_stop_transaction_response(value))
}

///|
pub fn StopTransactionResponse::to_json(self : StopTransactionResponse) -> Json {
  let fields : Map[String, Json] = Map([])
  match self.id_tag_info {
    Some(info) => fields.set("idTagInfo", info.to_json())
    None => ()
  }
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum DiagnosticsStatus {
  Idle
  Uploaded
  UploadFailed
  Uploading
}

///|
fn parse_diagnostics_status(
  value : String,
) -> DiagnosticsStatus raise ProtocolFailure {
  match value {
    "Idle" => Idle
    "Uploaded" => Uploaded
    "UploadFailed" => UploadFailed
    "Uploading" => Uploading
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
fn diagnostics_status_name(value : DiagnosticsStatus) -> String {
  match value {
    Idle => "Idle"
    Uploaded => "Uploaded"
    UploadFailed => "UploadFailed"
    Uploading => "Uploading"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct DiagnosticsStatusNotificationRequest {
  status : DiagnosticsStatus
}

///|
fn parse_diagnostics_status_notification(
  value : Json,
) -> DiagnosticsStatusNotificationRequest raise ProtocolFailure {
  { status: parse_diagnostics_status(required_string(value, "status")), }
}

///|
pub fn DiagnosticsStatusNotificationRequest::from_json(
  value : Json,
) -> Result[DiagnosticsStatusNotificationRequest, ProtocolError] {
  result_of(() => parse_diagnostics_status_notification(value))
}

///|
pub fn DiagnosticsStatusNotificationRequest::to_json(
  self : DiagnosticsStatusNotificationRequest,
) -> Json {
  Json::object({ "status": Json::string(diagnostics_status_name(self.status)) })
}

///|
#derive(Eq, @debug.Debug)
pub struct DiagnosticsStatusNotificationResponse {
  marker : Unit
}

///|
pub fn DiagnosticsStatusNotificationResponse::new() -> DiagnosticsStatusNotificationResponse {
  { marker: (), }
}

///|
fn parse_diagnostics_status_notification_response(
  value : Json,
) -> DiagnosticsStatusNotificationResponse raise ProtocolFailure {
  ensure_empty_object(value)
  DiagnosticsStatusNotificationResponse::new()
}

///|
pub fn DiagnosticsStatusNotificationResponse::from_json(
  value : Json,
) -> Result[DiagnosticsStatusNotificationResponse, ProtocolError] {
  result_of(() => parse_diagnostics_status_notification_response(value))
}

///|
pub fn DiagnosticsStatusNotificationResponse::to_json(
  self : DiagnosticsStatusNotificationResponse,
) -> Json {
  ignore(self)
  empty_object()
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum FirmwareStatus {
  Downloaded
  DownloadFailed
  Downloading
  Idle
  InstallationFailed
  Installing
  Installed
}

///|
fn parse_firmware_status(
  value : String,
) -> FirmwareStatus raise ProtocolFailure {
  match value {
    "Downloaded" => Downloaded
    "DownloadFailed" => DownloadFailed
    "Downloading" => Downloading
    "Idle" => Idle
    "InstallationFailed" => InstallationFailed
    "Installing" => Installing
    "Installed" => Installed
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
fn firmware_status_name(value : FirmwareStatus) -> String {
  match value {
    Downloaded => "Downloaded"
    DownloadFailed => "DownloadFailed"
    Downloading => "Downloading"
    Idle => "Idle"
    InstallationFailed => "InstallationFailed"
    Installing => "Installing"
    Installed => "Installed"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct FirmwareStatusNotificationRequest {
  status : FirmwareStatus
}

///|
fn parse_firmware_status_notification(
  value : Json,
) -> FirmwareStatusNotificationRequest raise ProtocolFailure {
  { status: parse_firmware_status(required_string(value, "status")), }
}

///|
pub fn FirmwareStatusNotificationRequest::from_json(
  value : Json,
) -> Result[FirmwareStatusNotificationRequest, ProtocolError] {
  result_of(() => parse_firmware_status_notification(value))
}

///|
pub fn FirmwareStatusNotificationRequest::to_json(
  self : FirmwareStatusNotificationRequest,
) -> Json {
  Json::object({ "status": Json::string(firmware_status_name(self.status)) })
}

///|
#derive(Eq, @debug.Debug)
pub struct FirmwareStatusNotificationResponse {
  marker : Unit
}

///|
pub fn FirmwareStatusNotificationResponse::new() -> FirmwareStatusNotificationResponse {
  { marker: (), }
}

///|
fn parse_firmware_status_notification_response(
  value : Json,
) -> FirmwareStatusNotificationResponse raise ProtocolFailure {
  ensure_empty_object(value)
  FirmwareStatusNotificationResponse::new()
}

///|
pub fn FirmwareStatusNotificationResponse::from_json(
  value : Json,
) -> Result[FirmwareStatusNotificationResponse, ProtocolError] {
  result_of(() => parse_firmware_status_notification_response(value))
}

///|
pub fn FirmwareStatusNotificationResponse::to_json(
  self : FirmwareStatusNotificationResponse,
) -> Json {
  ignore(self)
  empty_object()
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum CancelReservationStatus {
  Accepted
  Rejected
}

///|
fn parse_cancel_reservation_status(
  value : String,
) -> CancelReservationStatus raise ProtocolFailure {
  match value {
    "Accepted" => Accepted
    "Rejected" => Rejected
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
fn cancel_reservation_status_name(value : CancelReservationStatus) -> String {
  match value {
    Accepted => "Accepted"
    Rejected => "Rejected"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct CancelReservationRequest {
  reservation_id : Int32
}

///|
fn parse_cancel_reservation(
  value : Json,
) -> CancelReservationRequest raise ProtocolFailure {
  { reservation_id: required_nonnegative_int(value, "reservationId"), }
}

///|
pub fn CancelReservationRequest::from_json(
  value : Json,
) -> Result[CancelReservationRequest, ProtocolError] {
  result_of(() => parse_cancel_reservation(value))
}

///|
pub fn CancelReservationRequest::to_json(
  self : CancelReservationRequest,
) -> Json {
  Json::object({ "reservationId": int_json(self.reservation_id) })
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct CancelReservationResponse {
  status : CancelReservationStatus
}

///|
fn parse_cancel_reservation_response(
  value : Json,
) -> CancelReservationResponse raise ProtocolFailure {
  { status: parse_cancel_reservation_status(required_string(value, "status")), }
}

///|
pub fn CancelReservationResponse::from_json(
  value : Json,
) -> Result[CancelReservationResponse, ProtocolError] {
  result_of(() => parse_cancel_reservation_response(value))
}

///|
pub fn CancelReservationResponse::to_json(
  self : CancelReservationResponse,
) -> Json {
  Json::object({
    "status": Json::string(cancel_reservation_status_name(self.status)),
  })
}

///|
#derive(Eq, @debug.Debug)
pub struct ClearCacheRequest {
  marker : Unit
}

///|
pub fn ClearCacheRequest::new() -> ClearCacheRequest {
  { marker: (), }
}

///|
fn parse_clear_cache_request(
  value : Json,
) -> ClearCacheRequest raise ProtocolFailure {
  ensure_empty_object(value)
  ClearCacheRequest::new()
}

///|
pub fn ClearCacheRequest::from_json(
  value : Json,
) -> Result[ClearCacheRequest, ProtocolError] {
  result_of(() => parse_clear_cache_request(value))
}

///|
pub fn ClearCacheRequest::to_json(self : ClearCacheRequest) -> Json {
  ignore(self)
  empty_object()
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum ClearCacheStatus {
  Accepted
  Rejected
}

///|
fn parse_clear_cache_status(
  value : String,
) -> ClearCacheStatus raise ProtocolFailure {
  match value {
    "Accepted" => Accepted
    "Rejected" => Rejected
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
fn clear_cache_status_name(value : ClearCacheStatus) -> String {
  match value {
    Accepted => "Accepted"
    Rejected => "Rejected"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ClearCacheResponse {
  status : ClearCacheStatus
}

///|
fn parse_clear_cache_response(
  value : Json,
) -> ClearCacheResponse raise ProtocolFailure {
  { status: parse_clear_cache_status(required_string(value, "status")), }
}

///|
pub fn ClearCacheResponse::from_json(
  value : Json,
) -> Result[ClearCacheResponse, ProtocolError] {
  result_of(() => parse_clear_cache_response(value))
}

///|
pub fn ClearCacheResponse::to_json(self : ClearCacheResponse) -> Json {
  Json::object({ "status": Json::string(clear_cache_status_name(self.status)) })
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct UnlockConnectorRequest {
  connector_id : Int32
}

///|
fn parse_unlock_connector(
  value : Json,
) -> UnlockConnectorRequest raise ProtocolFailure {
  { connector_id: required_nonnegative_int(value, "connectorId"), }
}

///|
pub fn UnlockConnectorRequest::from_json(
  value : Json,
) -> Result[UnlockConnectorRequest, ProtocolError] {
  result_of(() => parse_unlock_connector(value))
}

///|
pub fn UnlockConnectorRequest::to_json(self : UnlockConnectorRequest) -> Json {
  Json::object({ "connectorId": int_json(self.connector_id) })
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum UnlockStatus {
  Unlocked
  UnlockFailed
  NotSupported
}

///|
fn parse_unlock_status(value : String) -> UnlockStatus raise ProtocolFailure {
  match value {
    "Unlocked" => Unlocked
    "UnlockFailed" => UnlockFailed
    "NotSupported" => NotSupported
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
fn unlock_status_name(value : UnlockStatus) -> String {
  match value {
    Unlocked => "Unlocked"
    UnlockFailed => "UnlockFailed"
    NotSupported => "NotSupported"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct UnlockConnectorResponse {
  status : UnlockStatus
}

///|
fn parse_unlock_connector_response(
  value : Json,
) -> UnlockConnectorResponse raise ProtocolFailure {
  { status: parse_unlock_status(required_string(value, "status")), }
}

///|
pub fn UnlockConnectorResponse::from_json(
  value : Json,
) -> Result[UnlockConnectorResponse, ProtocolError] {
  result_of(() => parse_unlock_connector_response(value))
}

///|
pub fn UnlockConnectorResponse::to_json(self : UnlockConnectorResponse) -> Json {
  Json::object({ "status": Json::string(unlock_status_name(self.status)) })
}
