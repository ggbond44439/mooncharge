///|
fn call_payload(text : String) -> Json raise {
  match @mooncharge.parse_frame(text) {
    Ok(@mooncharge.Call(_, _, payload)) => payload
    Ok(@mooncharge.CallResult(_, payload)) => payload
    _ => fail("expected a frame with an object payload")
  }
}

///|
test "GetDiagnostics round-trips scheduling and retry options" {
  let payload = call_payload(
    "[2,\"diag-1\",\"GetDiagnostics\",{\"location\":\"https://example.test/log.zip\",\"retries\":3,\"retryInterval\":60,\"startTime\":\"2026-11-22T00:00:00Z\",\"stopTime\":\"2026-11-22T01:00:00Z\"}]",
  )
  let request = match @mooncharge.GetDiagnosticsRequest::from_json(payload) {
    Ok(request) => request
    Err(_) => fail("failed to parse GetDiagnostics")
  }
  assert_eq(request.location, "https://example.test/log.zip")
  assert_eq(request.retries, Some(3))
  assert_eq(request.retry_interval, Some(60))
  assert_eq(request.start_time, Some("2026-11-22T00:00:00Z"))
  assert_eq(
    @mooncharge.GetDiagnosticsRequest::from_json(request.to_json()),
    Ok(request),
  )
}

///|
test "GetDiagnostics confirmation permits a missing file name" {
  let empty = match
    @mooncharge.GetDiagnosticsResponse::from_json(
      call_payload("[3,\"diag-2\",{}]"),
    ) {
    Ok(response) => response
    Err(_) => fail("failed to parse empty diagnostics confirmation")
  }
  assert_eq(empty.file_name, None)
  let named = match
    @mooncharge.GetDiagnosticsResponse::from_json(
      call_payload("[3,\"diag-3\",{\"fileName\":\"charge-point.log\"}]"),
    ) {
    Ok(response) => response
    Err(_) => fail("failed to parse named diagnostics confirmation")
  }
  assert_eq(named.file_name, Some("charge-point.log"))
  assert_eq(
    @mooncharge.GetDiagnosticsResponse::from_json(named.to_json()),
    Ok(named),
  )
}

///|
test "UpdateFirmware validates required fields and round-trips" {
  let payload = call_payload(
    "[2,\"fw-1\",\"UpdateFirmware\",{\"location\":\"https://example.test/fw.bin\",\"retrieveDate\":\"2026-11-23T02:00:00Z\",\"retries\":2,\"retryInterval\":300}]",
  )
  let request = match @mooncharge.UpdateFirmwareRequest::from_json(payload) {
    Ok(request) => request
    Err(_) => fail("failed to parse UpdateFirmware")
  }
  assert_eq(request.location, "https://example.test/fw.bin")
  assert_eq(request.retrieve_date, "2026-11-23T02:00:00Z")
  assert_eq(request.retries, Some(2))
  assert_eq(request.retry_interval, Some(300))
  assert_eq(
    @mooncharge.UpdateFirmwareRequest::from_json(request.to_json()),
    Ok(request),
  )
  assert_eq(
    @mooncharge.UpdateFirmwareRequest::from_json(
      call_payload(
        "[2,\"fw-bad\",\"UpdateFirmware\",{\"location\":\"https://example.test/fw.bin\"}]",
      ),
    ),
    Err(@mooncharge.ProtocolError::MissingField("retrieveDate")),
  )
  assert_eq(
    @mooncharge.UpdateFirmwareRequest::from_json(
      call_payload(
        "[2,\"fw-empty\",\"UpdateFirmware\",{\"location\":\"\",\"retrieveDate\":\"later\"}]",
      ),
    ),
    Err(@mooncharge.ProtocolError::InvalidField("location")),
  )
}

///|
test "firmware confirmation is a strict empty object" {
  let response = match
    @mooncharge.UpdateFirmwareResponse::from_json(
      call_payload("[3,\"fw-1\",{}]"),
    ) {
    Ok(response) => response
    Err(_) => fail("failed to parse firmware confirmation")
  }
  assert_eq(response.to_json(), call_payload("[3,\"fw-1\",{}]"))
  assert_eq(
    @mooncharge.UpdateFirmwareResponse::from_json(
      call_payload("[3,\"fw-1\",{\"accepted\":true}]"),
    ),
    Err(@mooncharge.ProtocolError::InvalidPayload),
  )
}

///|
test "maintenance actions dispatch from the central system" {
  let diagnostics = match
    @mooncharge.parse_frame(
      "[2,\"diag-4\",\"GetDiagnostics\",{\"location\":\"https://example.test/log.zip\"}]",
    ) {
    Ok(frame) => frame
    Err(_) => fail("failed to parse diagnostics frame")
  }
  match
    @mooncharge.dispatch_call(
      diagnostics,
      @mooncharge.MessageDirection::CentralSystemToChargePoint,
    ) {
    Ok(@mooncharge.TypedCall::GetDiagnostics(request)) =>
      assert_eq(request.location, "https://example.test/log.zip")
    _ => fail("expected typed GetDiagnostics")
  }
  let firmware = match
    @mooncharge.parse_frame(
      "[2,\"fw-2\",\"UpdateFirmware\",{\"location\":\"https://example.test/fw.bin\",\"retrieveDate\":\"2026-11-23T02:00:00Z\"}]",
    ) {
    Ok(frame) => frame
    Err(_) => fail("failed to parse firmware frame")
  }
  match
    @mooncharge.dispatch_call(
      firmware,
      @mooncharge.MessageDirection::CentralSystemToChargePoint,
    ) {
    Ok(@mooncharge.TypedCall::UpdateFirmware(request)) =>
      assert_eq(request.retrieve_date, "2026-11-23T02:00:00Z")
    _ => fail("expected typed UpdateFirmware")
  }
}
