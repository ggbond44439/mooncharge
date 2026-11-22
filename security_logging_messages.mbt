///|
#derive(Eq, @debug.Debug)
pub(all) enum LogType {
  DiagnosticsLog
  SecurityLog
}

///|
fn parse_log_type(value : String) -> LogType raise ProtocolFailure {
  match value {
    "DiagnosticsLog" => DiagnosticsLog
    "SecurityLog" => SecurityLog
    _ => refuse(UnsupportedValue("logType", value))
  }
}

///|
fn log_type_name(value : LogType) -> String {
  match value {
    DiagnosticsLog => "DiagnosticsLog"
    SecurityLog => "SecurityLog"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct LogParameters {
  remote_location : String
  oldest_timestamp : String?
  latest_timestamp : String?
}

///|
fn parse_log_parameters(value : Json) -> LogParameters raise ProtocolFailure {
  {
    remote_location: required_nonempty_string(value, "remoteLocation"),
    oldest_timestamp: optional_string(value, "oldestTimestamp"),
    latest_timestamp: optional_string(value, "latestTimestamp"),
  }
}

///|
pub fn LogParameters::from_json(
  value : Json,
) -> Result[LogParameters, ProtocolError] {
  result_of(() => parse_log_parameters(value))
}

///|
pub fn LogParameters::to_json(self : LogParameters) -> Json {
  let fields : Map[String, Json] = {
    "remoteLocation": Json::string(self.remote_location),
  }
  set_optional_string(fields, "oldestTimestamp", self.oldest_timestamp)
  set_optional_string(fields, "latestTimestamp", self.latest_timestamp)
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct GetLogRequest {
  log_type : LogType
  request_id : Int32
  log : LogParameters
  retries : Int32?
  retry_interval : Int32?
}

///|
fn parse_get_log_request(value : Json) -> GetLogRequest raise ProtocolFailure {
  {
    log_type: parse_log_type(required_string(value, "logType")),
    request_id: required_nonnegative_int(value, "requestId"),
    log: parse_log_parameters(required_object(value, "log")),
    retries: optional_nonnegative_int(value, "retries"),
    retry_interval: optional_nonnegative_int(value, "retryInterval"),
  }
}

///|
pub fn GetLogRequest::from_json(
  value : Json,
) -> Result[GetLogRequest, ProtocolError] {
  result_of(() => parse_get_log_request(value))
}

///|
pub fn GetLogRequest::to_json(self : GetLogRequest) -> Json {
  let fields : Map[String, Json] = {
    "logType": Json::string(log_type_name(self.log_type)),
    "requestId": int_json(self.request_id),
    "log": self.log.to_json(),
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
pub(all) enum GetLogStatus {
  Accepted
  Rejected
  AcceptedCanceled
}

///|
fn parse_get_log_status(value : String) -> GetLogStatus raise ProtocolFailure {
  match value {
    "Accepted" => Accepted
    "Rejected" => Rejected
    "AcceptedCanceled" => AcceptedCanceled
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
fn get_log_status_name(value : GetLogStatus) -> String {
  match value {
    Accepted => "Accepted"
    Rejected => "Rejected"
    AcceptedCanceled => "AcceptedCanceled"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct GetLogResponse {
  status : GetLogStatus
  filename : String?
}

///|
fn parse_get_log_response(value : Json) -> GetLogResponse raise ProtocolFailure {
  {
    status: parse_get_log_status(required_string(value, "status")),
    filename: optional_string(value, "filename"),
  }
}

///|
pub fn GetLogResponse::from_json(
  value : Json,
) -> Result[GetLogResponse, ProtocolError] {
  result_of(() => parse_get_log_response(value))
}

///|
pub fn GetLogResponse::to_json(self : GetLogResponse) -> Json {
  let fields : Map[String, Json] = {
    "status": Json::string(get_log_status_name(self.status)),
  }
  set_optional_string(fields, "filename", self.filename)
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum LogUploadStatus {
  BadMessage
  Idle
  NotSupportedOperation
  PermissionDenied
  Uploaded
  UploadFailure
  Uploading
}

///|
fn parse_log_upload_status(
  value : String,
) -> LogUploadStatus raise ProtocolFailure {
  match value {
    "BadMessage" => BadMessage
    "Idle" => Idle
    "NotSupportedOperation" => NotSupportedOperation
    "PermissionDenied" => PermissionDenied
    "Uploaded" => Uploaded
    "UploadFailure" => UploadFailure
    "Uploading" => Uploading
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
fn log_upload_status_name(value : LogUploadStatus) -> String {
  match value {
    BadMessage => "BadMessage"
    Idle => "Idle"
    NotSupportedOperation => "NotSupportedOperation"
    PermissionDenied => "PermissionDenied"
    Uploaded => "Uploaded"
    UploadFailure => "UploadFailure"
    Uploading => "Uploading"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct LogStatusNotificationRequest {
  status : LogUploadStatus
  request_id : Int32?
}

///|
fn parse_log_status_notification_request(
  value : Json,
) -> LogStatusNotificationRequest raise ProtocolFailure {
  {
    status: parse_log_upload_status(required_string(value, "status")),
    request_id: optional_nonnegative_int(value, "requestId"),
  }
}

///|
pub fn LogStatusNotificationRequest::from_json(
  value : Json,
) -> Result[LogStatusNotificationRequest, ProtocolError] {
  result_of(() => parse_log_status_notification_request(value))
}

///|
pub fn LogStatusNotificationRequest::to_json(
  self : LogStatusNotificationRequest,
) -> Json {
  let fields : Map[String, Json] = {
    "status": Json::string(log_upload_status_name(self.status)),
  }
  match self.request_id {
    Some(value) => fields.set("requestId", int_json(value))
    None => ()
  }
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub struct LogStatusNotificationResponse {
  marker : Unit
}

///|
pub fn LogStatusNotificationResponse::new() -> LogStatusNotificationResponse {
  { marker: (), }
}

///|
fn parse_log_status_notification_response(
  value : Json,
) -> LogStatusNotificationResponse raise ProtocolFailure {
  ensure_empty_object(value)
  LogStatusNotificationResponse::new()
}

///|
pub fn LogStatusNotificationResponse::from_json(
  value : Json,
) -> Result[LogStatusNotificationResponse, ProtocolError] {
  result_of(() => parse_log_status_notification_response(value))
}

///|
pub fn LogStatusNotificationResponse::to_json(
  self : LogStatusNotificationResponse,
) -> Json {
  ignore(self)
  empty_object()
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct SecurityEventNotificationRequest {
  event_type : String
  timestamp : String
  tech_info : String?
}

///|
fn parse_security_event_notification(
  value : Json,
) -> SecurityEventNotificationRequest raise ProtocolFailure {
  {
    event_type: required_nonempty_string(value, "type"),
    timestamp: required_nonempty_string(value, "timestamp"),
    tech_info: optional_string(value, "techInfo"),
  }
}

///|
pub fn SecurityEventNotificationRequest::from_json(
  value : Json,
) -> Result[SecurityEventNotificationRequest, ProtocolError] {
  result_of(() => parse_security_event_notification(value))
}

///|
pub fn SecurityEventNotificationRequest::to_json(
  self : SecurityEventNotificationRequest,
) -> Json {
  let fields : Map[String, Json] = {
    "type": Json::string(self.event_type),
    "timestamp": Json::string(self.timestamp),
  }
  set_optional_string(fields, "techInfo", self.tech_info)
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub struct SecurityEventNotificationResponse {
  marker : Unit
}

///|
pub fn SecurityEventNotificationResponse::new() -> SecurityEventNotificationResponse {
  { marker: (), }
}

///|
fn parse_security_event_notification_response(
  value : Json,
) -> SecurityEventNotificationResponse raise ProtocolFailure {
  ensure_empty_object(value)
  SecurityEventNotificationResponse::new()
}

///|
pub fn SecurityEventNotificationResponse::from_json(
  value : Json,
) -> Result[SecurityEventNotificationResponse, ProtocolError] {
  result_of(() => parse_security_event_notification_response(value))
}

///|
pub fn SecurityEventNotificationResponse::to_json(
  self : SecurityEventNotificationResponse,
) -> Json {
  ignore(self)
  empty_object()
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum SignedFirmwareStatus {
  Downloaded
  DownloadFailed
  Downloading
  DownloadScheduled
  DownloadPaused
  Idle
  InstallationFailed
  Installing
  Installed
  InstallRebooting
  InstallScheduled
  InstallVerificationFailed
  InvalidSignature
  SignatureVerified
}

///|
fn parse_signed_firmware_status(
  value : String,
) -> SignedFirmwareStatus raise ProtocolFailure {
  match value {
    "Downloaded" => Downloaded
    "DownloadFailed" => DownloadFailed
    "Downloading" => Downloading
    "DownloadScheduled" => DownloadScheduled
    "DownloadPaused" => DownloadPaused
    "Idle" => Idle
    "InstallationFailed" => InstallationFailed
    "Installing" => Installing
    "Installed" => Installed
    "InstallRebooting" => InstallRebooting
    "InstallScheduled" => InstallScheduled
    "InstallVerificationFailed" => InstallVerificationFailed
    "InvalidSignature" => InvalidSignature
    "SignatureVerified" => SignatureVerified
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
fn signed_firmware_status_name(value : SignedFirmwareStatus) -> String {
  match value {
    Downloaded => "Downloaded"
    DownloadFailed => "DownloadFailed"
    Downloading => "Downloading"
    DownloadScheduled => "DownloadScheduled"
    DownloadPaused => "DownloadPaused"
    Idle => "Idle"
    InstallationFailed => "InstallationFailed"
    Installing => "Installing"
    Installed => "Installed"
    InstallRebooting => "InstallRebooting"
    InstallScheduled => "InstallScheduled"
    InstallVerificationFailed => "InstallVerificationFailed"
    InvalidSignature => "InvalidSignature"
    SignatureVerified => "SignatureVerified"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct SignedFirmwareStatusNotificationRequest {
  status : SignedFirmwareStatus
  request_id : Int32?
}

///|
fn parse_signed_firmware_status_notification(
  value : Json,
) -> SignedFirmwareStatusNotificationRequest raise ProtocolFailure {
  {
    status: parse_signed_firmware_status(required_string(value, "status")),
    request_id: optional_nonnegative_int(value, "requestId"),
  }
}

///|
pub fn SignedFirmwareStatusNotificationRequest::from_json(
  value : Json,
) -> Result[SignedFirmwareStatusNotificationRequest, ProtocolError] {
  result_of(() => parse_signed_firmware_status_notification(value))
}

///|
pub fn SignedFirmwareStatusNotificationRequest::to_json(
  self : SignedFirmwareStatusNotificationRequest,
) -> Json {
  let fields : Map[String, Json] = {
    "status": Json::string(signed_firmware_status_name(self.status)),
  }
  match self.request_id {
    Some(value) => fields.set("requestId", int_json(value))
    None => ()
  }
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub struct SignedFirmwareStatusNotificationResponse {
  marker : Unit
}

///|
pub fn SignedFirmwareStatusNotificationResponse::new() -> SignedFirmwareStatusNotificationResponse {
  { marker: (), }
}

///|
fn parse_signed_firmware_status_notification_response(
  value : Json,
) -> SignedFirmwareStatusNotificationResponse raise ProtocolFailure {
  ensure_empty_object(value)
  SignedFirmwareStatusNotificationResponse::new()
}

///|
pub fn SignedFirmwareStatusNotificationResponse::from_json(
  value : Json,
) -> Result[SignedFirmwareStatusNotificationResponse, ProtocolError] {
  result_of(() => parse_signed_firmware_status_notification_response(value))
}

///|
pub fn SignedFirmwareStatusNotificationResponse::to_json(
  self : SignedFirmwareStatusNotificationResponse,
) -> Json {
  ignore(self)
  empty_object()
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct FirmwareImage {
  location : String
  retrieve_date_time : String
  install_date_time : String?
  signing_certificate : String
  signature : String
}

///|
fn parse_firmware_image(value : Json) -> FirmwareImage raise ProtocolFailure {
  {
    location: required_nonempty_string(value, "location"),
    retrieve_date_time: required_nonempty_string(value, "retrieveDateTime"),
    install_date_time: optional_string(value, "installDateTime"),
    signing_certificate: required_nonempty_string(value, "signingCertificate"),
    signature: required_nonempty_string(value, "signature"),
  }
}

///|
pub fn FirmwareImage::from_json(
  value : Json,
) -> Result[FirmwareImage, ProtocolError] {
  result_of(() => parse_firmware_image(value))
}

///|
pub fn FirmwareImage::to_json(self : FirmwareImage) -> Json {
  let fields : Map[String, Json] = {
    "location": Json::string(self.location),
    "retrieveDateTime": Json::string(self.retrieve_date_time),
    "signingCertificate": Json::string(self.signing_certificate),
    "signature": Json::string(self.signature),
  }
  set_optional_string(fields, "installDateTime", self.install_date_time)
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct SignedUpdateFirmwareRequest {
  request_id : Int32
  firmware : FirmwareImage
  retries : Int32?
  retry_interval : Int32?
}

///|
fn parse_signed_update_firmware_request(
  value : Json,
) -> SignedUpdateFirmwareRequest raise ProtocolFailure {
  {
    request_id: required_nonnegative_int(value, "requestId"),
    firmware: parse_firmware_image(required_object(value, "firmware")),
    retries: optional_nonnegative_int(value, "retries"),
    retry_interval: optional_nonnegative_int(value, "retryInterval"),
  }
}

///|
pub fn SignedUpdateFirmwareRequest::from_json(
  value : Json,
) -> Result[SignedUpdateFirmwareRequest, ProtocolError] {
  result_of(() => parse_signed_update_firmware_request(value))
}

///|
pub fn SignedUpdateFirmwareRequest::to_json(
  self : SignedUpdateFirmwareRequest,
) -> Json {
  let fields : Map[String, Json] = {
    "requestId": int_json(self.request_id),
    "firmware": self.firmware.to_json(),
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
pub(all) enum SignedUpdateFirmwareStatus {
  Accepted
  Rejected
  AcceptedCanceled
  InvalidCertificate
  RevokedCertificate
}

///|
fn parse_signed_update_firmware_status(
  value : String,
) -> SignedUpdateFirmwareStatus raise ProtocolFailure {
  match value {
    "Accepted" => Accepted
    "Rejected" => Rejected
    "AcceptedCanceled" => AcceptedCanceled
    "InvalidCertificate" => InvalidCertificate
    "RevokedCertificate" => RevokedCertificate
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
fn signed_update_firmware_status_name(
  value : SignedUpdateFirmwareStatus,
) -> String {
  match value {
    Accepted => "Accepted"
    Rejected => "Rejected"
    AcceptedCanceled => "AcceptedCanceled"
    InvalidCertificate => "InvalidCertificate"
    RevokedCertificate => "RevokedCertificate"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct SignedUpdateFirmwareResponse {
  status : SignedUpdateFirmwareStatus
}

///|
fn parse_signed_update_firmware_response(
  value : Json,
) -> SignedUpdateFirmwareResponse raise ProtocolFailure {
  {
    status: parse_signed_update_firmware_status(
      required_string(value, "status"),
    ),
  }
}

///|
pub fn SignedUpdateFirmwareResponse::from_json(
  value : Json,
) -> Result[SignedUpdateFirmwareResponse, ProtocolError] {
  result_of(() => parse_signed_update_firmware_response(value))
}

///|
pub fn SignedUpdateFirmwareResponse::to_json(
  self : SignedUpdateFirmwareResponse,
) -> Json {
  Json::object({
    "status": Json::string(signed_update_firmware_status_name(self.status)),
  })
}
