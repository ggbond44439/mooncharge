///|
fn security_payload(text : String) -> Json raise {
  match @mooncharge.parse_frame(text) {
    Ok(@mooncharge.Call(_, _, payload)) => payload
    Ok(@mooncharge.CallResult(_, payload)) => payload
    _ => fail("expected a frame with an object payload")
  }
}

///|
test "GetLog captures log type, time range and retry options" {
  let request = match
    @mooncharge.GetLogRequest::from_json(
      security_payload(
        "[2,\"log-1\",\"GetLog\",{\"logType\":\"SecurityLog\",\"requestId\":9,\"log\":{\"remoteLocation\":\"https://example.test/security.log\",\"oldestTimestamp\":\"2026-11-22T00:00:00Z\",\"latestTimestamp\":\"2026-11-22T01:00:00Z\"},\"retries\":2,\"retryInterval\":30}]",
      ),
    ) {
    Ok(request) => request
    Err(_) => fail("failed to parse GetLog")
  }
  assert_eq(request.log_type, @mooncharge.LogType::SecurityLog)
  assert_eq(request.request_id, 9)
  assert_eq(request.log.remote_location, "https://example.test/security.log")
  assert_eq(request.retries, Some(2))
  assert_eq(request.retry_interval, Some(30))
  assert_eq(
    @mooncharge.GetLogRequest::from_json(request.to_json()),
    Ok(request),
  )
  assert_eq(
    @mooncharge.GetLogResponse::from_json(
      security_payload(
        "[3,\"log-1\",{\"status\":\"Accepted\",\"filename\":\"security.log\"}]",
      ),
    ),
    Ok({
      status: @mooncharge.GetLogStatus::Accepted,
      filename: Some("security.log"),
    }),
  )
}

///|
test "GetLog rejects missing required log parameters" {
  assert_eq(
    @mooncharge.GetLogRequest::from_json(
      security_payload(
        "[2,\"log-bad\",\"GetLog\",{\"logType\":\"SecurityLog\",\"requestId\":9,\"log\":{}}]",
      ),
    ),
    Err(@mooncharge.ProtocolError::MissingField("remoteLocation")),
  )
  assert_eq(
    @mooncharge.GetLogRequest::from_json(
      security_payload(
        "[2,\"log-bad\",\"GetLog\",{\"logType\":\"AuditLog\",\"requestId\":9,\"log\":{\"remoteLocation\":\"https://example.test\"}}]",
      ),
    ),
    Err(@mooncharge.ProtocolError::UnsupportedValue("logType", "AuditLog")),
  )
}

///|
test "log status and security event notifications round-trip" {
  let upload = match
    @mooncharge.LogStatusNotificationRequest::from_json(
      security_payload(
        "[2,\"log-status\",\"LogStatusNotification\",{\"status\":\"UploadFailure\",\"requestId\":9}]",
      ),
    ) {
    Ok(request) => request
    Err(_) => fail("failed to parse LogStatusNotification")
  }
  assert_eq(upload.status, @mooncharge.LogUploadStatus::UploadFailure)
  assert_eq(upload.request_id, Some(9))
  assert_eq(
    @mooncharge.LogStatusNotificationRequest::from_json(upload.to_json()),
    Ok(upload),
  )
  let event = match
    @mooncharge.SecurityEventNotificationRequest::from_json(
      security_payload(
        "[2,\"security-1\",\"SecurityEventNotification\",{\"type\":\"FirmwareUpdateStarted\",\"timestamp\":\"2026-11-22T02:00:00Z\",\"techInfo\":\"signed image\"}]",
      ),
    ) {
    Ok(request) => request
    Err(_) => fail("failed to parse SecurityEventNotification")
  }
  assert_eq(event.event_type, "FirmwareUpdateStarted")
  assert_eq(event.tech_info, Some("signed image"))
  assert_eq(
    @mooncharge.SecurityEventNotificationRequest::from_json(event.to_json()),
    Ok(event),
  )
}

///|
test "signed firmware status supports verification states" {
  let request = match
    @mooncharge.SignedFirmwareStatusNotificationRequest::from_json(
      security_payload(
        "[2,\"signed-status\",\"SignedFirmwareStatusNotification\",{\"status\":\"InvalidSignature\",\"requestId\":41}]",
      ),
    ) {
    Ok(request) => request
    Err(_) => fail("failed to parse signed firmware status")
  }
  assert_eq(request.status, @mooncharge.SignedFirmwareStatus::InvalidSignature)
  assert_eq(request.request_id, Some(41))
  assert_eq(
    @mooncharge.SignedFirmwareStatusNotificationRequest::from_json(
      request.to_json(),
    ),
    Ok(request),
  )
  assert_eq(
    @mooncharge.SignedFirmwareStatusNotificationRequest::from_json(
      security_payload(
        "[2,\"signed-status\",\"SignedFirmwareStatusNotification\",{\"status\":\"Unknown\"}]",
      ),
    ),
    Err(@mooncharge.ProtocolError::UnsupportedValue("status", "Unknown")),
  )
}

///|
test "SignedUpdateFirmware validates signature material and status" {
  let request = match
    @mooncharge.SignedUpdateFirmwareRequest::from_json(
      security_payload(
        "[2,\"signed-update\",\"SignedUpdateFirmware\",{\"requestId\":41,\"retries\":2,\"retryInterval\":60,\"firmware\":{\"location\":\"https://example.test/fw.bin\",\"retrieveDateTime\":\"2026-11-23T02:00:00Z\",\"installDateTime\":\"2026-11-23T03:00:00Z\",\"signingCertificate\":\"certificate\",\"signature\":\"signature\"}}]",
      ),
    ) {
    Ok(request) => request
    Err(_) => fail("failed to parse SignedUpdateFirmware")
  }
  assert_eq(request.request_id, 41)
  assert_eq(request.firmware.signing_certificate, "certificate")
  assert_eq(request.firmware.signature, "signature")
  assert_eq(
    @mooncharge.SignedUpdateFirmwareRequest::from_json(request.to_json()),
    Ok(request),
  )
  assert_eq(
    @mooncharge.SignedUpdateFirmwareResponse::from_json(
      security_payload(
        "[3,\"signed-update\",{\"status\":\"InvalidCertificate\"}]",
      ),
    ),
    Ok({ status: @mooncharge.SignedUpdateFirmwareStatus::InvalidCertificate, }),
  )
  assert_eq(
    @mooncharge.SignedUpdateFirmwareRequest::from_json(
      security_payload(
        "[2,\"signed-update\",\"SignedUpdateFirmware\",{\"requestId\":41,\"firmware\":{\"location\":\"https://example.test/fw.bin\",\"retrieveDateTime\":\"2026-11-23T02:00:00Z\",\"signingCertificate\":\"certificate\"}}]",
      ),
    ),
    Err(@mooncharge.ProtocolError::MissingField("signature")),
  )
}

///|
test "logging and security actions dispatch in the correct direction" {
  let get_log = match
    @mooncharge.parse_frame(
      "[2,\"log-dispatch\",\"GetLog\",{\"logType\":\"DiagnosticsLog\",\"requestId\":1,\"log\":{\"remoteLocation\":\"https://example.test/log\"}}]",
    ) {
    Ok(frame) => frame
    Err(_) => fail("failed to parse GetLog frame")
  }
  match
    @mooncharge.dispatch_call(
      get_log,
      @mooncharge.MessageDirection::CentralSystemToChargePoint,
    ) {
    Ok(@mooncharge.TypedCall::GetLog(request)) =>
      assert_eq(request.log_type, @mooncharge.LogType::DiagnosticsLog)
    _ => fail("expected typed GetLog")
  }
  let security_event = match
    @mooncharge.parse_frame(
      "[2,\"security-dispatch\",\"SecurityEventNotification\",{\"type\":\"SettingsChanged\",\"timestamp\":\"2026-11-22T04:00:00Z\"}]",
    ) {
    Ok(frame) => frame
    Err(_) => fail("failed to parse security event frame")
  }
  match
    @mooncharge.dispatch_call(
      security_event,
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
    ) {
    Ok(@mooncharge.TypedCall::SecurityEventNotification(request)) =>
      assert_eq(request.event_type, "SettingsChanged")
    _ => fail("expected typed SecurityEventNotification")
  }
}
