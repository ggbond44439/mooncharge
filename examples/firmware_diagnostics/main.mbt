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
fn main raise {
  let diagnostics_frame = match
    @mooncharge.parse_frame(
      "[2,\"diag-1\",\"GetDiagnostics\",{\"location\":\"https://example.test/log.zip\",\"retries\":3,\"retryInterval\":60}]",
    ) {
    Ok(frame) => frame
    Err(_) => fail("failed to parse diagnostics request")
  }
  let diagnostics = match
    @mooncharge.dispatch_call(
      diagnostics_frame,
      @mooncharge.MessageDirection::CentralSystemToChargePoint,
    ) {
    Ok(@mooncharge.TypedCall::GetDiagnostics(request)) => request
    _ => fail("expected typed GetDiagnostics")
  }
  let diagnostics_response = match
    @mooncharge.GetDiagnosticsResponse::from_json(
      payload("[3,\"diag-1\",{\"fileName\":\"charge-point.log\"}]"),
    ) {
    Ok(response) => response
    Err(_) => fail("failed to parse diagnostics confirmation")
  }
  println(
    "diagnostics_location=\{diagnostics.location} retries=\{option_int(diagnostics.retries)} file=\{option_text(diagnostics_response.file_name)}",
  )
  let firmware = match
    @mooncharge.UpdateFirmwareRequest::from_json(
      payload(
        "[2,\"fw-1\",\"UpdateFirmware\",{\"location\":\"https://example.test/fw.bin\",\"retrieveDate\":\"2026-11-23T02:00:00Z\"}]",
      ),
    ) {
    Ok(request) => request
    Err(_) => fail("failed to parse firmware request")
  }
  let confirmation = @mooncharge.UpdateFirmwareResponse::new()
  println(
    "firmware_date=\{firmware.retrieve_date} confirmation_empty=\{confirmation.to_json() == payload("[3,\"fw-1\",{}]")}",
  )
}
