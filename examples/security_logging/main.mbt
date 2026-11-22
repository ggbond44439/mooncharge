///|
fn payload(text : String) -> Json raise {
  match @mooncharge.parse_frame(text) {
    Ok(@mooncharge.Call(_, _, value)) | Ok(@mooncharge.CallResult(_, value)) =>
      value
    _ => fail("expected a JSON-RPC frame")
  }
}

///|
fn option_text(value : String?) -> String {
  match value {
    Some(text) => text
    None => "none"
  }
}

///|
fn option_int(value : Int32?) -> String {
  match value {
    Some(number) => number.to_string()
    None => "none"
  }
}

///|
fn log_type(value : @mooncharge.LogType) -> String {
  match value {
    @mooncharge.LogType::DiagnosticsLog => "DiagnosticsLog"
    @mooncharge.LogType::SecurityLog => "SecurityLog"
  }
}

///|
fn signed_status(value : @mooncharge.SignedUpdateFirmwareStatus) -> String {
  match value {
    @mooncharge.SignedUpdateFirmwareStatus::Accepted => "Accepted"
    @mooncharge.SignedUpdateFirmwareStatus::Rejected => "Rejected"
    @mooncharge.SignedUpdateFirmwareStatus::AcceptedCanceled =>
      "AcceptedCanceled"
    @mooncharge.SignedUpdateFirmwareStatus::InvalidCertificate =>
      "InvalidCertificate"
    @mooncharge.SignedUpdateFirmwareStatus::RevokedCertificate =>
      "RevokedCertificate"
  }
}

///|
fn main raise {
  let log = match
    @mooncharge.GetLogRequest::from_json(
      payload(
        "[2,\"log-1\",\"GetLog\",{\"logType\":\"SecurityLog\",\"requestId\":9,\"log\":{\"remoteLocation\":\"https://example.test/security.log\"},\"retries\":2}]",
      ),
    ) {
    Ok(request) => request
    Err(_) => fail("failed to parse GetLog")
  }
  println(
    "log_type=\{log_type(log.log_type)} request=\{log.request_id} retries=\{option_int(log.retries)} location=\{log.log.remote_location}",
  )
  let event = match
    @mooncharge.SecurityEventNotificationRequest::from_json(
      payload(
        "[2,\"event-1\",\"SecurityEventNotification\",{\"type\":\"FirmwareUpdateStarted\",\"timestamp\":\"2026-11-22T02:00:00Z\",\"techInfo\":\"signed image\"}]",
      ),
    ) {
    Ok(request) => request
    Err(_) => fail("failed to parse security event")
  }
  println(
    "event=\{event.event_type} at=\{event.timestamp} info=\{option_text(event.tech_info)}",
  )
  let update = match
    @mooncharge.SignedUpdateFirmwareRequest::from_json(
      payload(
        "[2,\"update-1\",\"SignedUpdateFirmware\",{\"requestId\":41,\"firmware\":{\"location\":\"https://example.test/fw.bin\",\"retrieveDateTime\":\"2026-11-23T02:00:00Z\",\"signingCertificate\":\"certificate\",\"signature\":\"signature\"}}]",
      ),
    ) {
    Ok(request) => request
    Err(_) => fail("failed to parse signed update")
  }
  let response = match
    @mooncharge.SignedUpdateFirmwareResponse::from_json(
      payload("[3,\"update-1\",{\"status\":\"Accepted\"}]"),
    ) {
    Ok(response) => response
    Err(_) => fail("failed to parse signed update response")
  }
  println(
    "signed_request=\{update.request_id} signed=\{update.firmware.signature} status=\{signed_status(response.status)}",
  )
}
