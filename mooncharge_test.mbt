///|
fn parsed_frame(text : String) -> @mooncharge.Frame raise {
  match @mooncharge.parse_frame(text) {
    Ok(frame) => frame
    Err(error) => fail(error.message())
  }
}

///|
test "CALL frames preserve ids, actions, and object payloads" {
  let frame = parsed_frame(
    "[2,\"req-1\",\"BootNotification\",{\"chargePointVendor\":\"MoonCharge\",\"chargePointModel\":\"M1\"}]",
  )
  match frame {
    Call(id, action, payload) => {
      assert_eq(id, @mooncharge.MessageId::Text("req-1"))
      assert_eq(action, "BootNotification")
      match @mooncharge.BootNotificationRequest::from_json(payload) {
        Ok(request) => {
          assert_eq(request.charge_point_vendor, "MoonCharge")
          assert_eq(request.charge_point_model, "M1")
        }
        Err(error) => fail(error.message())
      }
    }
    _ => fail("expected CALL")
  }
}

///|
test "CALLRESULT and CALLERROR round-trip through the wire encoder" {
  let result = parsed_frame("[3,17,{\"status\":\"Accepted\"}]")
  assert_eq(@mooncharge.parse_frame(result.encode()), Ok(result))
  let error = parsed_frame("[4,\"x\",\"SecurityError\",\"bad signature\",{}]")
  assert_eq(@mooncharge.parse_frame(error.encode()), Ok(error))
}

///|
test "unknown OCPP error codes remain forward-compatible" {
  match parsed_frame("[4,1,\"FutureError\",\"future\",{}]") {
    CallError(_, error) =>
      assert_eq(error.code, @mooncharge.RpcErrorCode::Unknown("FutureError"))
    _ => fail("expected CALLERROR")
  }
}

///|
test "malformed frame structure is rejected" {
  assert_eq(
    @mooncharge.parse_frame("{\"type\":2}"),
    Err(@mooncharge.ProtocolError::FrameMustBeArray),
  )
  assert_eq(
    @mooncharge.parse_frame("[2,\"id\",\"Heartbeat\"]"),
    Err(@mooncharge.ProtocolError::InvalidFrameLength(3)),
  )
  assert_eq(
    @mooncharge.parse_frame("[2,\"id\",\"Heartbeat\",[]]"),
    Err(@mooncharge.ProtocolError::InvalidPayload),
  )
  assert_eq(
    @mooncharge.parse_frame("[9,\"id\",{}]"),
    Err(@mooncharge.ProtocolError::UnsupportedFrameType(9)),
  )
}

///|
test "request and confirmation directions are explicit" {
  assert_eq(
    @mooncharge.action_direction("StartTransaction", true),
    Ok(@mooncharge.MessageDirection::ChargePointToCentralSystem),
  )
  assert_eq(
    @mooncharge.action_direction("StartTransaction", false),
    Ok(@mooncharge.MessageDirection::CentralSystemToChargePoint),
  )
  assert_eq(
    @mooncharge.action_direction("SetChargingProfile", true),
    Ok(@mooncharge.MessageDirection::CentralSystemToChargePoint),
  )
}

///|
test "StartTransaction decodes meter values without float coercion" {
  let payload = match
    parsed_frame(
      "[2,\"42\",\"StartTransaction\",{\"connectorId\":2,\"idTag\":\"RFID-1\",\"meterStart\":12345,\"timestamp\":\"2026-11-18T08:00:00Z\"}]",
    ) {
    Call(_, _, payload) => payload
    _ => return
  }
  match @mooncharge.StartTransactionRequest::from_json(payload) {
    Ok(request) => {
      assert_eq(request.connector_id, 2)
      assert_eq(request.meter_start, 12345)
      assert_eq(request.reservation_id, None)
      assert_eq(request.id_tag, "RFID-1")
    }
    Err(error) => fail(error.message())
  }
}

///|
test "MeterValues rejects an empty sampled-value list" {
  let payload = match
    parsed_frame(
      "[2,\"m1\",\"MeterValues\",{\"connectorId\":1,\"meterValue\":[]}]",
    ) {
    Call(_, _, payload) => payload
    _ => return
  }
  assert_eq(
    @mooncharge.MeterValuesRequest::from_json(payload),
    Err(@mooncharge.ProtocolError::InvalidField("meterValue")),
  )
}

///|
fn period(
  start_period : Int32,
  limit : Double,
) -> @mooncharge.ChargingSchedulePeriod {
  { start_period, limit, number_phases: None, }
}

///|
fn profile(
  id : Int32,
  purpose : @mooncharge.ChargingProfilePurpose,
  stack_level : Int32,
  transaction_id : Int32?,
  periods : Array[@mooncharge.ChargingSchedulePeriod],
) -> @mooncharge.ChargingProfile {
  {
    charging_profile_id: id,
    transaction_id,
    stack_level,
    charging_profile_purpose: purpose,
    charging_profile_kind: @mooncharge.ChargingProfileKind::Absolute,
    recurrency_kind: None,
    valid_from: None,
    valid_to: None,
    charging_schedule: {
      start_schedule: None,
      duration: Some(3600),
      min_charging_rate: None,
      charging_rate_unit: @mooncharge.ChargingRateUnit::Amps,
      periods,
    },
  }
}

///|
test "transaction profile beats default profile" {
  let profiles = [
    profile(10, @mooncharge.ChargingProfilePurpose::TxDefaultProfile, 1, None, [
      period(0, 16.0),
    ]),
    profile(20, @mooncharge.ChargingProfilePurpose::TxProfile, 1, Some(7), [
      period(0, 32.0),
      period(900, 24.0),
    ]),
  ]
  assert_eq(
    @mooncharge.evaluate_charging_profiles(profiles, Some(7), 1200),
    Ok({
      limit: 24.0,
      unit: @mooncharge.ChargingRateUnit::Amps,
      profile_id: 20,
      capped_by_charge_point_max: false,
      number_phases: None,
    }),
  )
}

///|
test "charge-point maximum caps the selected transaction profile" {
  let profiles = [
    profile(
      1,
      @mooncharge.ChargingProfilePurpose::ChargePointMaxProfile,
      5,
      None,
      [period(0, 20.0)],
    ),
    profile(2, @mooncharge.ChargingProfilePurpose::TxDefaultProfile, 1, None, [
      period(0, 32.0),
    ]),
  ]
  let decision = match
    @mooncharge.evaluate_charging_profiles(profiles, None, 10) {
    Ok(decision) => decision
    Err(_) => fail("expected an active decision")
  }
  assert_eq(decision.limit, 20.0)
  assert_true(decision.capped_by_charge_point_max)
}

///|
test "higher stack level and schedule expiry are honored" {
  let profiles = [
    profile(1, @mooncharge.ChargingProfilePurpose::TxDefaultProfile, 1, None, [
      period(0, 10.0),
    ]),
    profile(2, @mooncharge.ChargingProfilePurpose::TxDefaultProfile, 3, None, [
      period(0, 30.0),
    ]),
  ]
  assert_eq(
    @mooncharge.evaluate_charging_profiles(profiles, None, 3599),
    Ok({
      limit: 30.0,
      unit: @mooncharge.ChargingRateUnit::Amps,
      profile_id: 2,
      capped_by_charge_point_max: false,
      number_phases: None,
    }),
  )
  assert_eq(
    @mooncharge.evaluate_charging_profiles(profiles, None, 3600),
    Err(@mooncharge.ChargingProfileError::NoActiveProfile),
  )
}

///|
test "connector lifecycle prevents double transactions and meter rollback" {
  let connector = match @mooncharge.ConnectorSession::new(1) {
    Ok(connector) => connector
    Err(_) => fail("expected valid connector")
  }
  let active = match
    connector.begin_transaction(99, "RFID-1", 1000, "2026-11-18T08:00:00Z") {
    Ok(active) => active
    Err(_) => fail("expected transaction to start")
  }
  assert_eq(active.status, @mooncharge.ChargePointStatus::Preparing)
  assert_eq(
    active.begin_transaction(100, "RFID-2", 0, "later"),
    Err(@mooncharge.SessionError::TransactionAlreadyActive(99)),
  )
  assert_eq(
    active.finish_transaction(
      99,
      900,
      "2026-11-18T09:00:00Z",
      Some(@mooncharge.StopReason::Local),
    ),
    Err(@mooncharge.SessionError::MeterRegression(1000, 900)),
  )
  let finished = match
    active.finish_transaction(
      99,
      2500,
      "2026-11-18T09:00:00Z",
      Some(@mooncharge.StopReason::Local),
    ) {
    Ok(finished) => finished
    Err(_) => fail("expected transaction to finish")
  }
  assert_eq(finished.status, @mooncharge.ChargePointStatus::Finishing)
  let released = match finished.release_transaction(99) {
    Ok(released) => released
    Err(_) => fail("expected transaction release")
  }
  assert_eq(released.status, @mooncharge.ChargePointStatus::Available)
  assert_eq(released.transaction, None)
}

///|
test "CLI parses a frame and reports stable summary fields" {
  let output = @mooncharge.run_cli(["frame", "[2,\"r1\",\"Heartbeat\",{}]"])
  assert_eq(output.exit_code, 0)
  assert_eq(output.stdout, "kind=call id=r1 action=Heartbeat")
}

///|
test "CLI evaluates a profile document" {
  let document = "{\"chargingProfileId\":8,\"stackLevel\":1,\"chargingProfilePurpose\":\"TxDefaultProfile\",\"chargingProfileKind\":\"Absolute\",\"chargingSchedule\":{\"chargingRateUnit\":\"W\",\"duration\":600,\"chargingSchedulePeriod\":[{\"startPeriod\":0,\"limit\":22000}]}}"
  let output = @mooncharge.run_cli(["profile", document, "120"])
  assert_eq(output.exit_code, 0)
  assert_eq(output.stdout, "limit=22000 unit=W profile=8 capped=false")
}

///|
test "CLI rejects invalid commands with a non-zero status" {
  let output = @mooncharge.run_cli(["action", "StartTransaction", "sideways"])
  assert_eq(output.exit_code, 2)
  assert_true(output.stderr.contains("action expects"))
}

///|
test "remote start and stop commands round-trip" {
  let start_payload = match
    parsed_frame(
      "[2,\"rs-1\",\"RemoteStartTransaction\",{\"idTag\":\"RFID-9\",\"connectorId\":2}]",
    ) {
    Call(_, _, payload) => payload
    _ => return
  }
  let start = match
    @mooncharge.RemoteStartTransactionRequest::from_json(start_payload) {
    Ok(value) => value
    Err(error) => fail(error.message())
  }
  assert_eq(start.id_tag, "RFID-9")
  assert_eq(start.connector_id, Some(2))
  let stop_payload = match
    parsed_frame(
      "[2,\"rs-2\",\"RemoteStopTransaction\",{\"transactionId\":77}]",
    ) {
    Call(_, _, payload) => payload
    _ => return
  }
  match @mooncharge.RemoteStopTransactionRequest::from_json(stop_payload) {
    Ok(stop) => assert_eq(stop.transaction_id, 77)
    Err(error) => fail(error.message())
  }
}

///|
test "reset and availability commands are strictly enum-checked" {
  let reset_payload = match
    parsed_frame("[2,\"reset-1\",\"Reset\",{\"type\":\"Soft\"}]") {
    Call(_, _, payload) => payload
    _ => return
  }
  let reset = match @mooncharge.ResetRequest::from_json(reset_payload) {
    Ok(value) => value
    Err(error) => fail(error.message())
  }
  assert_eq(reset.kind, @mooncharge.ResetType::Soft)
  let availability_payload = match
    parsed_frame(
      "[2,\"avail-1\",\"ChangeAvailability\",{\"connectorId\":1,\"type\":\"Inoperative\"}]",
    ) {
    Call(_, _, payload) => payload
    _ => return
  }
  match @mooncharge.ChangeAvailabilityRequest::from_json(availability_payload) {
    Ok(value) => {
      assert_eq(value.connector_id, 1)
      assert_eq(value.kind, @mooncharge.AvailabilityType::Inoperative)
    }
    Err(error) => fail(error.message())
  }
}

///|
test "configuration commands preserve readonly and unknown keys" {
  let change_payload = match
    parsed_frame(
      "[2,\"cfg-1\",\"ChangeConfiguration\",{\"key\":\"HeartbeatInterval\",\"value\":\"60\"}]",
    ) {
    Call(_, _, payload) => payload
    _ => return
  }
  match @mooncharge.ChangeConfigurationRequest::from_json(change_payload) {
    Ok(request) => {
      assert_eq(request.key, "HeartbeatInterval")
      assert_eq(request.value, "60")
    }
    Err(error) => fail(error.message())
  }
  let response_payload = match
    parsed_frame(
      "[3,\"cfg-1\",{\"configurationKey\":[{\"key\":\"HeartbeatInterval\",\"readonly\":false,\"value\":\"60\"}],\"unknownKey\":[\"Missing\"]}]",
    ) {
    CallResult(_, payload) => payload
    _ => return
  }
  let response = match
    @mooncharge.GetConfigurationResponse::from_json(response_payload) {
    Ok(value) => value
    Err(error) => fail(error.message())
  }
  assert_eq(response.configuration_key.length(), 1)
  assert_eq(response.unknown_key, ["Missing"])
  assert_eq(response.configuration_key[0].value, Some("60"))
}

///|
test "SetChargingProfile reuses the validated profile model" {
  let payload = match
    parsed_frame(
      "[2,\"profile-1\",\"SetChargingProfile\",{\"connectorId\":1,\"csChargingProfiles\":{\"chargingProfileId\":8,\"stackLevel\":2,\"chargingProfilePurpose\":\"TxProfile\",\"transactionId\":44,\"chargingProfileKind\":\"Absolute\",\"chargingSchedule\":{\"chargingRateUnit\":\"A\",\"duration\":600,\"chargingSchedulePeriod\":[{\"startPeriod\":0,\"limit\":16}]}}}]",
    ) {
    Call(_, _, payload) => payload
    _ => return
  }
  match @mooncharge.SetChargingProfileRequest::from_json(payload) {
    Ok(request) => {
      assert_eq(request.connector_id, 1)
      assert_eq(request.cs_charging_profiles.charging_profile_id, 8)
      assert_eq(request.cs_charging_profiles.transaction_id, Some(44))
    }
    Err(error) => fail(error.message())
  }
  let clear_payload = match
    parsed_frame(
      "[2,\"clear-1\",\"ClearChargingProfile\",{\"connectorId\":1,\"chargingProfilePurpose\":\"TxProfile\",\"stackLevel\":2}]",
    ) {
    Call(_, _, payload) => payload
    _ => return
  }
  let clear = match
    @mooncharge.ClearChargingProfileRequest::from_json(clear_payload) {
    Ok(value) => value
    Err(error) => fail(error.message())
  }
  assert_eq(
    clear.charging_profile_purpose,
    Some(@mooncharge.ChargingProfilePurpose::TxProfile),
  )
}

///|
test "typed dispatch checks direction and preserves extensions" {
  let call = parsed_frame(
    "[2,\"remote-1\",\"RemoteStartTransaction\",{\"idTag\":\"RFID-4\"}]",
  )
  match
    @mooncharge.dispatch_call(
      call,
      @mooncharge.MessageDirection::CentralSystemToChargePoint,
    ) {
    Ok(@mooncharge.TypedCall::RemoteStartTransaction(request)) =>
      assert_eq(request.id_tag, "RFID-4")
    _ => fail("expected typed RemoteStartTransaction")
  }
  assert_eq(
    @mooncharge.dispatch_call(
      call,
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
    ),
    Err(
      @mooncharge.DispatchError::WrongDirection(
        @mooncharge.MessageDirection::CentralSystemToChargePoint,
        @mooncharge.MessageDirection::ChargePointToCentralSystem,
      ),
    ),
  )
  let extension = parsed_frame(
    "[2,\"ext-1\",\"VendorExtension\",{\"feature\":\"reserve\"}]",
  )
  match
    @mooncharge.dispatch_call(
      extension,
      @mooncharge.MessageDirection::CentralSystemToChargePoint,
    ) {
    Ok(@mooncharge.TypedCall::UnsupportedAction(action, _)) =>
      assert_eq(action, "VendorExtension")
    _ => fail("expected an extension action")
  }
}

///|
test "DataTransfer keeps opaque vendor payloads intact" {
  let frame = parsed_frame(
    "[2,\"data-1\",\"DataTransfer\",{\"vendorId\":\"com.example.meter\",\"messageId\":\"sample\",\"data\":\"AQID\"}]",
  )
  match
    @mooncharge.dispatch_call(
      frame,
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
    ) {
    Ok(@mooncharge.TypedCall::DataTransfer(request)) => {
      assert_eq(request.vendor_id, "com.example.meter")
      assert_eq(request.data, Some("AQID"))
    }
    _ => fail("expected typed DataTransfer")
  }
}

///|
test "CLI dispatches typed calls with explicit direction" {
  let output = @mooncharge.run_cli([
    "dispatch", "cp", "[2,\"auth-1\",\"Authorize\",{\"idTag\":\"RFID-1\"}]",
  ])
  assert_eq(output.exit_code, 0)
  assert_eq(
    output.stdout,
    "typed=Authorize direction=charge-point-to-central-system",
  )
}

///|
test "OCPP 1.6J catalog covers every registered action" {
  let actions = @mooncharge.OcppAction::all()
  let specs = @mooncharge.action_specs()
  assert_eq(actions.length(), 39)
  assert_eq(specs.length(), actions.length())
  for action in actions {
    let spec = match @mooncharge.find_action_spec(action.name()) {
      Some(spec) => spec
      None => fail("missing action specification")
    }
    assert_eq(spec.request_direction, action.request_direction())
    assert_eq(@mooncharge.OcppAction::parse(spec.action), Some(action))
  }
}

///|
test "conformance summary reflects the current typed coverage" {
  assert_eq(@mooncharge.conformance_summary(), {
    total_actions: 39,
    typed_requests: 34,
    typed_responses: 34,
    catalog_only_requests: 5,
    catalog_only_responses: 5,
  })
}

///|
test "payload audit checks direction and required fields" {
  let frame = parsed_frame(
    "[2,\"start-1\",\"StartTransaction\",{\"connectorId\":1,\"idTag\":\"RFID-1\",\"meterStart\":0,\"timestamp\":\"2026-11-20T00:00:00Z\"}]",
  )
  let report = @mooncharge.audit_frame(
    frame,
    @mooncharge.MessageDirection::ChargePointToCentralSystem,
  )
  assert_true(report.passed())
  assert_eq(
    @mooncharge.audit_payload(
      "StartTransaction",
      @mooncharge.PayloadPhase::Request,
      @mooncharge.MessageDirection::CentralSystemToChargePoint,
      match frame {
        @mooncharge.Call(_, _, payload) => payload
        _ => fail("expected CALL")
      },
    ),
    {
      action: "StartTransaction",
      phase: @mooncharge.PayloadPhase::Request,
      issues: [
        @mooncharge.ConformanceIssue::WrongDirection(
          @mooncharge.MessageDirection::ChargePointToCentralSystem,
          @mooncharge.MessageDirection::CentralSystemToChargePoint,
        ),
      ],
    },
  )
}

///|
test "payload audit reports missing required schema fields" {
  let frame = parsed_frame(
    "[2,\"start-2\",\"StartTransaction\",{\"connectorId\":1,\"idTag\":\"RFID-1\"}]",
  )
  let report = @mooncharge.audit_frame(
    frame,
    @mooncharge.MessageDirection::ChargePointToCentralSystem,
  )
  assert_false(report.passed())
  assert_eq(report.issues, [
    @mooncharge.ConformanceIssue::MissingRequiredField(
      @mooncharge.PayloadPhase::Request,
      "meterStart",
    ),
    @mooncharge.ConformanceIssue::MissingRequiredField(
      @mooncharge.PayloadPhase::Request,
      "timestamp",
    ),
  ])
}

///|
test "BootNotification confirmation uses the standard interval field" {
  let payload = match
    parsed_frame(
      "[3,\"boot-1\",{\"status\":\"Accepted\",\"currentTime\":\"2026-11-20T00:00:00Z\",\"interval\":300}]",
    ) {
    @mooncharge.CallResult(_, payload) => payload
    _ => fail("expected CALLRESULT")
  }
  let report = @mooncharge.audit_payload(
    "BootNotification",
    @mooncharge.PayloadPhase::Confirmation,
    @mooncharge.MessageDirection::CentralSystemToChargePoint,
    payload,
  )
  assert_true(report.passed())
  let response = match
    @mooncharge.BootNotificationResponse::from_json(payload) {
    Ok(response) => response
    Err(error) => fail(error.message())
  }
  assert_eq(response.interval, 300)
}

///|
test "unknown actions and non-CALL frames fail the baseline audit" {
  let frame = parsed_frame("[2,\"x\",\"UnknownAction\",{}]")
  assert_eq(
    @mooncharge.audit_frame(
      frame,
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
    ),
    {
      action: "UnknownAction",
      phase: @mooncharge.PayloadPhase::Request,
      issues: [@mooncharge.ConformanceIssue::UnknownAction("UnknownAction")],
    },
  )
  let result = parsed_frame("[3,\"x\",{}]")
  assert_eq(
    @mooncharge.audit_frame(
      result,
      @mooncharge.MessageDirection::CentralSystemToChargePoint,
    ),
    {
      action: "",
      phase: @mooncharge.PayloadPhase::Request,
      issues: [@mooncharge.ConformanceIssue::NotACall],
    },
  )
}

///|
test "CLI exposes conformance summary action and audit" {
  let summary = @mooncharge.run_cli(["conformance", "summary"])
  assert_eq(summary.exit_code, 0)
  assert_eq(
    summary.stdout,
    "actions=39 typed_requests=34 typed_responses=34 catalog_only_requests=5 catalog_only_responses=5",
  )
  let action = @mooncharge.run_cli(["conformance", "action", "StartTransaction"])
  assert_eq(action.exit_code, 0)
  assert_eq(
    action.stdout,
    "action=StartTransaction direction=charge-point-to-central-system request=typed response=typed request_required=[connectorId,idTag,meterStart,timestamp] response_required=[idTagInfo,transactionId]",
  )
  let invalid = @mooncharge.run_cli([
    "conformance", "audit", "cp", "[2,\"bad\",\"StartTransaction\",{\"connectorId\":1}]",
  ])
  assert_eq(invalid.exit_code, 1)
  assert_true(invalid.stdout.contains("missing-field:request:idTag"))
}

///|
test "frame limits reject invalid configurations and oversized input" {
  assert_eq(
    @mooncharge.FrameLimits::new(max_input_bytes=0).validate(),
    Err(@mooncharge.ProtocolError::InvalidLimits("max_input_bytes")),
  )
  let text = "[2,\"x\",\"Heartbeat\",{}]"
  match
    @mooncharge.parse_frame_with_limits(
      text,
      @mooncharge.FrameLimits::new(max_input_bytes=4),
    ) {
    Err(@mooncharge.ProtocolError::InputTooLong("frame", 4, actual)) =>
      assert_true(actual > 4)
    _ => fail("expected input size rejection")
  }
}

///|
test "frame limits count UTF-8 bytes for ids and actions" {
  match
    @mooncharge.parse_frame_with_limits(
      "[2,\"😀\",\"Heartbeat\",{}]",
      @mooncharge.FrameLimits::new(max_message_id_bytes=3),
    ) {
    Err(@mooncharge.ProtocolError::FieldTooLong("messageId", 3, 4)) => ()
    _ => fail("expected UTF-8 id rejection")
  }
  assert_eq(
    @mooncharge.parse_frame_with_limits(
      "[2,\"x\",\"HeartbeatLong\",{}]",
      @mooncharge.FrameLimits::new(max_action_bytes=8),
    ),
    Err(@mooncharge.ProtocolError::FieldTooLong("action", 8, 13)),
  )
}

///|
test "frame limits reject excessive payload fields and nesting" {
  assert_eq(
    @mooncharge.parse_frame_with_limits(
      "[2,\"x\",\"Heartbeat\",{\"a\":1,\"b\":2}]",
      @mooncharge.FrameLimits::new(max_payload_fields=1),
    ),
    Err(@mooncharge.ProtocolError::TooManyPayloadFields(1, 2)),
  )
  assert_eq(
    @mooncharge.parse_frame_with_limits(
      "[2,\"x\",\"Heartbeat\",{\"a\":[[[1]]]}]",
      @mooncharge.FrameLimits::new(max_nesting_depth=2),
    ),
    Err(@mooncharge.ProtocolError::InvalidJson),
  )
}

///|
test "duplicate JSON keys are rejected by default" {
  assert_eq(
    @mooncharge.parse_frame("[2,\"x\",\"Heartbeat\",{\"a\":1,\"a\":2}]"),
    Err(@mooncharge.ProtocolError::InvalidJson),
  )
  match
    @mooncharge.parse_frame_with_limits(
      "[2,\"x\",\"Heartbeat\",{\"a\":1,\"a\":2}]",
      @mooncharge.FrameLimits::new(reject_duplicate_keys=false),
    ) {
    Ok(@mooncharge.Call(_, _, payload)) =>
      assert_eq(payload.stringify(), "{\"a\":2}")
    _ => fail("expected duplicate-key compatibility mode")
  }
}

///|
test "versioned parsing binds OCPP 1.6J explicitly" {
  let text = "[2,\"v1\",\"Heartbeat\",{}]"
  let value = match
    @mooncharge.parse_versioned_frame(@mooncharge.OcppVersion::V16J, text) {
    Ok(value) => value
    Err(error) => fail(error.message())
  }
  assert_eq(value.version, @mooncharge.OcppVersion::V16J)
  assert_eq(value.encode(), text)
  assert_eq(@mooncharge.OcppVersion::V16J.label(), "1.6J")
  assert_true(@mooncharge.OcppVersion::V16J.is_supported())
}

///|
test "unsupported protocol versions fail closed across versioned APIs" {
  assert_eq(
    @mooncharge.parse_versioned_frame(
      @mooncharge.OcppVersion::V201,
      "[2,\"v2\",\"Heartbeat\",{}]",
    ),
    Err(
      @mooncharge.ProtocolError::UnsupportedProtocolVersion(
        @mooncharge.OcppVersion::V201,
      ),
    ),
  )
  assert_eq(
    @mooncharge.action_specs_for(@mooncharge.OcppVersion::V201),
    Err(
      @mooncharge.ProtocolError::UnsupportedProtocolVersion(
        @mooncharge.OcppVersion::V201,
      ),
    ),
  )
  let frame = parsed_frame("[2,\"v2\",\"Heartbeat\",{}]")
  let value : @mooncharge.VersionedFrame = {
    version: @mooncharge.OcppVersion::V201,
    frame,
  }
  assert_eq(
    @mooncharge.dispatch_versioned_call(
      value,
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
    ),
    Err(
      @mooncharge.DispatchError::UnsupportedVersion(
        @mooncharge.OcppVersion::V201,
      ),
    ),
  )
  assert_eq(
    @mooncharge.audit_versioned_frame(
      value,
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
    ),
    {
      action: "",
      phase: @mooncharge.PayloadPhase::Request,
      issues: [
        @mooncharge.ConformanceIssue::UnsupportedVersion(
          @mooncharge.OcppVersion::V201,
        ),
      ],
    },
  )
}

///|
test "CLI exposes supported versions and version-bound parsing" {
  assert_eq(
    @mooncharge.run_cli(["version"]).stdout,
    "supported=1.6J known=1.6J,2.0.1",
  )
  assert_eq(
    @mooncharge.run_cli(["versioned", "1.6J", "[2,\"hb\",\"Heartbeat\",{}]"]).stdout,
    "version=1.6J kind=call id=hb action=Heartbeat",
  )
  let unsupported = @mooncharge.run_cli([
    "versioned", "2.0.1", "[2,\"hb\",\"Heartbeat\",{}]",
  ])
  assert_eq(unsupported.exit_code, 2)
  assert_true(unsupported.stderr.contains("unsupported OCPP version 2.0.1"))
}

///|
test "core request payloads are typed and dispatched" {
  let heartbeat = parsed_frame("[2,\"hb\",\"Heartbeat\",{}]")
  match
    @mooncharge.dispatch_call(
      heartbeat,
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
    ) {
    Ok(@mooncharge.TypedCall::Heartbeat(_)) => ()
    _ => fail("expected typed Heartbeat")
  }
  let diagnostics = parsed_frame(
    "[2,\"diag\",\"DiagnosticsStatusNotification\",{\"status\":\"Uploading\"}]",
  )
  match
    @mooncharge.dispatch_call(
      diagnostics,
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
    ) {
    Ok(@mooncharge.TypedCall::DiagnosticsStatusNotification(request)) =>
      assert_eq(request.status, @mooncharge.DiagnosticsStatus::Uploading)
    _ => fail("expected typed DiagnosticsStatusNotification")
  }
  let firmware = parsed_frame(
    "[2,\"fw\",\"FirmwareStatusNotification\",{\"status\":\"Installed\"}]",
  )
  match
    @mooncharge.dispatch_call(
      firmware,
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
    ) {
    Ok(@mooncharge.TypedCall::FirmwareStatusNotification(request)) =>
      assert_eq(request.status, @mooncharge.FirmwareStatus::Installed)
    _ => fail("expected typed FirmwareStatusNotification")
  }
  let cancel = parsed_frame(
    "[2,\"cancel\",\"CancelReservation\",{\"reservationId\":12}]",
  )
  match
    @mooncharge.dispatch_call(
      cancel,
      @mooncharge.MessageDirection::CentralSystemToChargePoint,
    ) {
    Ok(@mooncharge.TypedCall::CancelReservation(request)) =>
      assert_eq(request.reservation_id, 12)
    _ => fail("expected typed CancelReservation")
  }
  let clear = parsed_frame("[2,\"cache\",\"ClearCache\",{}]")
  match
    @mooncharge.dispatch_call(
      clear,
      @mooncharge.MessageDirection::CentralSystemToChargePoint,
    ) {
    Ok(@mooncharge.TypedCall::ClearCache(_)) => ()
    _ => fail("expected typed ClearCache")
  }
  let unlock = parsed_frame(
    "[2,\"unlock\",\"UnlockConnector\",{\"connectorId\":2}]",
  )
  match
    @mooncharge.dispatch_call(
      unlock,
      @mooncharge.MessageDirection::CentralSystemToChargePoint,
    ) {
    Ok(@mooncharge.TypedCall::UnlockConnector(request)) =>
      assert_eq(request.connector_id, 2)
    _ => fail("expected typed UnlockConnector")
  }
}

///|
test "empty and optional core confirmations remain strict" {
  let meter_payload = match parsed_frame("[3,\"meter\",{}]") {
    @mooncharge.CallResult(_, payload) => payload
    _ => fail("expected CALLRESULT")
  }
  assert_eq(
    @mooncharge.MeterValuesResponse::from_json(meter_payload),
    Ok(@mooncharge.MeterValuesResponse::new()),
  )
  let stop_payload = match
    parsed_frame("[3,\"stop\",{\"idTagInfo\":{\"status\":\"Accepted\"}}]") {
    @mooncharge.CallResult(_, payload) => payload
    _ => fail("expected CALLRESULT")
  }
  let stop = match
    @mooncharge.StopTransactionResponse::from_json(stop_payload) {
    Ok(value) => value
    Err(error) => fail(error.message())
  }
  assert_eq(
    stop.id_tag_info,
    Some({
      status: @mooncharge.AuthorizationStatus::Accepted,
      expiry_date: None,
      parent_id_tag: None,
    }),
  )
  assert_eq(
    @mooncharge.ClearCacheStatus::Accepted,
    @mooncharge.ClearCacheStatus::Accepted,
  )
}

///|
test "pending calls correlate results by message id and action" {
  let table = match
    @mooncharge.PendingCallTable::new(@mooncharge.OcppVersion::V16J, 2) {
    Ok(table) => table
    Err(_) => fail("expected pending-call table")
  }
  assert_eq(
    table.insert(
      @mooncharge.MessageId::Text("start-1"),
      "StartTransaction",
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
      100,
    ),
    Ok(()),
  )
  let response = parsed_frame(
    "[3,\"start-1\",{\"transactionId\":7,\"idTagInfo\":{\"status\":\"Accepted\"}}]",
  )
  let correlated = match
    table.complete(
      response,
      @mooncharge.MessageDirection::CentralSystemToChargePoint,
      50,
    ) {
    Ok(value) => value
    Err(_) => fail("expected correlated response")
  }
  match correlated {
    @mooncharge.CorrelatedResponse::Result(id, action, payload) => {
      assert_eq(id, @mooncharge.MessageId::Text("start-1"))
      assert_eq(action, "StartTransaction")
      assert_true(payload.stringify().contains("\"transactionId\":7"))
    }
    _ => fail("expected successful result")
  }
  assert_eq(table.pending_count(), 0)
}

///|
test "pending calls preserve CALLERROR as a correlated response" {
  let table = match
    @mooncharge.PendingCallTable::new(@mooncharge.OcppVersion::V16J, 2) {
    Ok(table) => table
    Err(_) => fail("expected pending-call table")
  }
  assert_eq(
    table.insert(
      @mooncharge.MessageId::Number("42"),
      "Reset",
      @mooncharge.MessageDirection::CentralSystemToChargePoint,
      200,
    ),
    Ok(()),
  )
  let response = parsed_frame("[4,42,\"SecurityError\",\"rejected\",{}]")
  match
    table.complete(
      response,
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
      100,
    ) {
    Ok(@mooncharge.CorrelatedResponse::Error(id, action, error)) => {
      assert_eq(id, @mooncharge.MessageId::Number("42"))
      assert_eq(action, "Reset")
      assert_eq(error.code, @mooncharge.RpcErrorCode::SecurityError)
    }
    _ => fail("expected correlated CALLERROR")
  }
}

///|
test "pending calls enforce direction capacity duplicate and null ids" {
  let table = match
    @mooncharge.PendingCallTable::new(@mooncharge.OcppVersion::V16J, 1) {
    Ok(table) => table
    Err(_) => fail("expected pending-call table")
  }
  assert_eq(
    table.insert(
      @mooncharge.MessageId::Null,
      "Heartbeat",
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
      100,
    ),
    Err(@mooncharge.CorrelationError::NullMessageId),
  )
  assert_eq(
    table.insert(
      @mooncharge.MessageId::Text("x"),
      "Heartbeat",
      @mooncharge.MessageDirection::CentralSystemToChargePoint,
      100,
    ),
    Err(
      @mooncharge.CorrelationError::WrongDirection(
        @mooncharge.MessageDirection::ChargePointToCentralSystem,
        @mooncharge.MessageDirection::CentralSystemToChargePoint,
      ),
    ),
  )
  assert_eq(
    table.insert(
      @mooncharge.MessageId::Text("x"),
      "Heartbeat",
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
      100,
    ),
    Ok(()),
  )
  assert_eq(
    table.insert(
      @mooncharge.MessageId::Text("x"),
      "Heartbeat",
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
      100,
    ),
    Err(
      @mooncharge.CorrelationError::DuplicateMessageId(
        @mooncharge.MessageId::Text("x"),
      ),
    ),
  )
  assert_eq(
    table.insert(
      @mooncharge.MessageId::Text("y"),
      "Heartbeat",
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
      100,
    ),
    Err(@mooncharge.CorrelationError::TableFull(1)),
  )
}

///|
test "pending calls reject wrong response direction and unknown ids" {
  let table = match
    @mooncharge.PendingCallTable::new(@mooncharge.OcppVersion::V16J, 2) {
    Ok(table) => table
    Err(_) => fail("expected pending-call table")
  }
  assert_eq(
    table.insert(
      @mooncharge.MessageId::Text("hb"),
      "Heartbeat",
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
      100,
    ),
    Ok(()),
  )
  let response = parsed_frame(
    "[3,\"hb\",{\"currentTime\":\"2026-11-20T00:00:00Z\"}]",
  )
  assert_eq(
    table.complete(
      response,
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
      50,
    ),
    Err(
      @mooncharge.CorrelationError::WrongDirection(
        @mooncharge.MessageDirection::CentralSystemToChargePoint,
        @mooncharge.MessageDirection::ChargePointToCentralSystem,
      ),
    ),
  )
  assert_eq(table.pending_count(), 1)
  assert_eq(
    table.complete(
      parsed_frame("[3,\"missing\",{}]"),
      @mooncharge.MessageDirection::CentralSystemToChargePoint,
      50,
    ),
    Err(
      @mooncharge.CorrelationError::UnknownMessageId(
        @mooncharge.MessageId::Text("missing"),
      ),
    ),
  )
}

///|
test "pending calls expire and enforce version matching" {
  let table = match
    @mooncharge.PendingCallTable::new(@mooncharge.OcppVersion::V16J, 2) {
    Ok(table) => table
    Err(_) => fail("expected pending-call table")
  }
  assert_eq(
    table.insert(
      @mooncharge.MessageId::Text("expired"),
      "Heartbeat",
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
      10,
    ),
    Ok(()),
  )
  let expired = table.expire(10)
  assert_eq(expired.length(), 1)
  assert_eq(table.pending_count(), 0)
  let frame = parsed_frame("[2,\"v2\",\"Heartbeat\",{}]")
  let unsupported : @mooncharge.VersionedFrame = {
    version: @mooncharge.OcppVersion::V201,
    frame,
  }
  assert_eq(
    table.complete_versioned(
      unsupported,
      @mooncharge.MessageDirection::CentralSystemToChargePoint,
      5,
    ),
    Err(
      @mooncharge.CorrelationError::VersionMismatch(
        @mooncharge.OcppVersion::V16J,
        @mooncharge.OcppVersion::V201,
      ),
    ),
  )
}

///|
test "pending calls reject invalid construction and completion frames" {
  assert_eq(
    @mooncharge.PendingCallTable::new(@mooncharge.OcppVersion::V16J, 0),
    Err(@mooncharge.CorrelationError::InvalidMaxPending(0)),
  )
  assert_eq(
    @mooncharge.PendingCallTable::new(@mooncharge.OcppVersion::V201, 1),
    Err(
      @mooncharge.CorrelationError::UnsupportedVersion(
        @mooncharge.OcppVersion::V201,
      ),
    ),
  )
  let table = match
    @mooncharge.PendingCallTable::new(@mooncharge.OcppVersion::V16J, 1) {
    Ok(table) => table
    Err(_) => fail("expected pending-call table")
  }
  assert_eq(
    table.complete(
      parsed_frame("[2,\"not-response\",\"Heartbeat\",{}]"),
      @mooncharge.MessageDirection::CentralSystemToChargePoint,
      0,
    ),
    Err(@mooncharge.CorrelationError::NotAResponse),
  )
  assert_eq(
    table.insert(
      @mooncharge.MessageId::Text("late"),
      "Heartbeat",
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
      10,
    ),
    Ok(()),
  )
  assert_eq(
    table.complete(
      parsed_frame("[3,\"late\",{\"currentTime\":\"later\"}]"),
      @mooncharge.MessageDirection::CentralSystemToChargePoint,
      10,
    ),
    Err(
      @mooncharge.CorrelationError::Expired(@mooncharge.MessageId::Text("late")),
    ),
  )
  assert_eq(table.pending_count(), 0)
}

///|
test "station session manages multiple connectors and summaries" {
  let station = match @mooncharge.ChargePointSession::new([1, 2, 3]) {
    Ok(station) => station
    Err(_) => fail("failed to create station")
  }
  assert_eq(station.connectors.length(), 3)
  assert_eq(
    station.add_connector(2),
    Err(@mooncharge.StationError::DuplicateConnectorId(2)),
  )
  assert_eq(station.add_connector(4), Ok(()))
  assert_eq(station.remove_connector(4), Ok(()))
  assert_eq(station.summary(), {
    total_connectors: 3,
    available: 3,
    unavailable: 0,
    faulted: 0,
    charging: 0,
    active_transactions: 0,
    station_mode: @mooncharge.StationMode::Operative,
  })
  assert_true(station.is_consistent())
}

///|
test "station batch status updates are atomic" {
  let station = match @mooncharge.ChargePointSession::new([1, 2]) {
    Ok(station) => station
    Err(_) => fail("failed to create station")
  }
  assert_eq(
    station.apply_status_batch([
      { connector_id: 1, status: @mooncharge.ChargePointStatus::Preparing, },
      { connector_id: 9, status: @mooncharge.ChargePointStatus::Faulted, },
    ]),
    Err(@mooncharge.StationError::ConnectorNotFound(9)),
  )
  assert_eq(
    station.connector(1).unwrap().status,
    @mooncharge.ChargePointStatus::Available,
  )
  assert_eq(
    station.apply_status_batch([
      { connector_id: 1, status: @mooncharge.ChargePointStatus::Preparing, },
      { connector_id: 2, status: @mooncharge.ChargePointStatus::Unavailable, },
    ]),
    Ok(()),
  )
  assert_eq(station.summary().unavailable, 1)
}

///|
test "station availability is blocked by active transactions" {
  let station = match @mooncharge.ChargePointSession::new([1, 2]) {
    Ok(station) => station
    Err(_) => fail("failed to create station")
  }
  station.connectors[0] = station.connectors[0]
    .begin_transaction(7, "RFID-1", 10, "2026-11-21T00:00:00Z")
    .unwrap()
  assert_eq(
    station.change_availability(0, @mooncharge.AvailabilityType::Inoperative),
    Err(@mooncharge.StationError::ActiveTransactionPreventsAvailability(0)),
  )
  assert_eq(station.station_mode, @mooncharge.StationMode::Operative)
  assert_eq(
    station.connector(2).unwrap().status,
    @mooncharge.ChargePointStatus::Available,
  )
}

///|
test "station-wide availability and fault recovery preserve transaction state" {
  let station = match @mooncharge.ChargePointSession::new([1, 2]) {
    Ok(station) => station
    Err(_) => fail("failed to create station")
  }
  assert_eq(
    station.change_availability(0, @mooncharge.AvailabilityType::Inoperative),
    Ok(()),
  )
  assert_eq(station.station_mode, @mooncharge.StationMode::Inoperative)
  assert_eq(station.summary().unavailable, 2)
  assert_eq(
    station.change_availability(0, @mooncharge.AvailabilityType::Operative),
    Ok(()),
  )
  assert_eq(station.summary().available, 2)
  station.connectors[0] = station.connectors[0]
    .begin_transaction(9, "RFID-2", 0, "2026-11-21T00:00:00Z")
    .unwrap()
    .apply_status(@mooncharge.ChargePointStatus::Faulted)
  assert_eq(station.clear_connector_fault(1), Ok(()))
  assert_eq(
    station.connector(1).unwrap().status,
    @mooncharge.ChargePointStatus::Charging,
  )
}

///|
test "station consistency diagnostics expose corrupted snapshots" {
  let corrupted : @mooncharge.ChargePointSession = {
    station_mode: @mooncharge.StationMode::Inoperative,
    connectors: [
      {
        connector_id: 1,
        status: @mooncharge.ChargePointStatus::Charging,
        transaction: None,
      },
      {
        connector_id: 2,
        status: @mooncharge.ChargePointStatus::Available,
        transaction: Some({
          transaction_id: 3,
          id_tag: "RFID",
          meter_start: 0,
          start_timestamp: "start",
          meter_stop: None,
          stop_timestamp: None,
          stop_reason: None,
        }),
      },
    ],
  }
  assert_eq(corrupted.consistency_issues(), [
    @mooncharge.StationConsistencyIssue::ChargingWithoutTransaction(1),
    @mooncharge.StationConsistencyIssue::AvailableWithTransaction(2),
    @mooncharge.StationConsistencyIssue::InoperativeWithActiveTransaction(2),
  ])
}

///|
test "reservation messages and lifecycle are typed" {
  let payload = match
    parsed_frame(
      "[2,\"reserve\",\"ReserveNow\",{\"connectorId\":1,\"expiryDate\":\"2026-11-21T01:00:00Z\",\"idTag\":\"RFID-R\",\"reservationId\":22}]",
    ) {
    @mooncharge.Call(_, _, payload) => payload
    _ => fail("expected CALL")
  }
  let request = match @mooncharge.ReserveNowRequest::from_json(payload) {
    Ok(request) => request
    Err(error) => fail(error.message())
  }
  assert_eq(request.connector_id, 1)
  let book = @mooncharge.ReservationBook::new()
  match book.reserve(request, 100) {
    Ok(reservation) => assert_eq(reservation.reservation_id, 22)
    Err(_) => fail("failed to reserve connector")
  }
  assert_eq(book.count(), 1)
  assert_eq(
    book.reserve(
      {
        connector_id: 2,
        expiry_date: "later",
        id_tag: "RFID-X",
        reservation_id: 22,
        parent_id_tag: None,
      },
      50,
    ),
    Err(@mooncharge.ReservationError::DuplicateReservationId(22)),
  )
  match book.claim(1, "RFID-R", Some(22), 50) {
    Ok(reservation) => assert_eq(reservation.connector_id, 1)
    Err(_) => fail("failed to claim reservation")
  }
  assert_eq(book.count(), 0)
}

///|
test "reservation claim rejects mismatches and expiry" {
  let book = @mooncharge.ReservationBook::new()
  match
    book.reserve(
      {
        connector_id: 3,
        expiry_date: "soon",
        id_tag: "RFID-3",
        reservation_id: 30,
        parent_id_tag: None,
      },
      10,
    ) {
    Ok(_) => ()
    Err(_) => fail("failed to reserve")
  }
  assert_eq(
    book.claim(3, "WRONG", Some(30), 5),
    Err(@mooncharge.ReservationError::IdTagMismatch("RFID-3", "WRONG")),
  )
  assert_eq(
    book.claim(2, "RFID-3", Some(30), 5),
    Err(@mooncharge.ReservationError::ConnectorMismatch(3, 2)),
  )
  assert_eq(
    book.claim(3, "RFID-3", Some(30), 10),
    Err(@mooncharge.ReservationError::ExpiredReservation(30)),
  )
  assert_eq(book.count(), 0)
}

///|
test "local authorization list supports full and differential updates" {
  let payload = match
    parsed_frame(
      "[2,\"local\",\"SendLocalList\",{\"listVersion\":1,\"updateType\":\"Full\",\"localAuthorizationList\":[{\"idTag\":\"A\",\"idTagInfo\":{\"status\":\"Accepted\"}}]}]",
    ) {
    @mooncharge.Call(_, _, payload) => payload
    _ => fail("expected CALL")
  }
  let request = match @mooncharge.SendLocalListRequest::from_json(payload) {
    Ok(request) => request
    Err(error) => fail(error.message())
  }
  let store = @mooncharge.LocalAuthorizationStore::new()
  assert_eq(store.apply(request), Ok(()))
  assert_eq(store.list_version(), 1)
  let auth = match store.authorize("A") {
    Some(info) => info
    None => fail("missing local authorization")
  }
  assert_eq(auth.status, @mooncharge.AuthorizationStatus::Accepted)
  let differential_payload = match
    parsed_frame(
      "[2,\"local2\",\"SendLocalList\",{\"listVersion\":2,\"updateType\":\"Differential\",\"localAuthorizationList\":[{\"idTag\":\"A\",\"idTagInfo\":{\"status\":\"Blocked\"}},{\"idTag\":\"B\",\"idTagInfo\":{\"status\":\"Accepted\"}}]}]",
    ) {
    @mooncharge.Call(_, _, payload) => payload
    _ => fail("expected CALL")
  }
  let differential = match
    @mooncharge.SendLocalListRequest::from_json(differential_payload) {
    Ok(request) => request
    Err(error) => fail(error.message())
  }
  assert_eq(store.apply(differential), Ok(()))
  let blocked = match store.authorize("A") {
    Some(info) => info
    None => fail("missing updated authorization")
  }
  assert_eq(blocked.status, @mooncharge.AuthorizationStatus::Blocked)
  assert_eq(
    store.authorize("B").unwrap().status,
    @mooncharge.AuthorizationStatus::Accepted,
  )
}

///|
test "local authorization updates reject stale versions and duplicate tags" {
  let store = @mooncharge.LocalAuthorizationStore::new()
  let duplicate : @mooncharge.SendLocalListRequest = {
    list_version: 1,
    update_type: @mooncharge.LocalListUpdateType::Full,
    local_authorization_list: [
      {
        id_tag: "A",
        id_tag_info: {
          status: @mooncharge.AuthorizationStatus::Accepted,
          expiry_date: None,
          parent_id_tag: None,
        },
      },
      {
        id_tag: "A",
        id_tag_info: {
          status: @mooncharge.AuthorizationStatus::Blocked,
          expiry_date: None,
          parent_id_tag: None,
        },
      },
    ],
  }
  assert_eq(
    store.apply(duplicate),
    Err(@mooncharge.LocalAuthorizationError::DuplicateIdTag("A")),
  )
  let version_one : @mooncharge.SendLocalListRequest = {
    list_version: 1,
    update_type: @mooncharge.LocalListUpdateType::Full,
    local_authorization_list: [],
  }
  assert_eq(store.apply(version_one), Ok(()))
  assert_eq(
    store.apply(version_one),
    Err(@mooncharge.LocalAuthorizationError::VersionMismatch(1, 1)),
  )
}

///|
fn timed_profile(
  profile : @mooncharge.ChargingProfile,
  validity : @mooncharge.EpochInterval?,
  schedule_start_epoch : Int64,
  transaction_start_epoch : Int64?,
) -> @mooncharge.TimedChargingProfile {
  { profile, validity, schedule_start_epoch, transaction_start_epoch, }
}

///|
test "timed profiles honor caller-mapped validity windows" {
  let profile = profile(
    10,
    @mooncharge.ChargingProfilePurpose::TxDefaultProfile,
    1,
    None,
    [period(0, 16.0)],
  )
  let validity = @mooncharge.EpochInterval::new(900, Some(2_000)).unwrap()
  let timed = timed_profile(profile, Some(validity), 1_000, None)
  assert_eq(
    @mooncharge.evaluate_timed_charging_profiles([timed], None, 899),
    Err(@mooncharge.ChargingProfileError::NoActiveProfile),
  )
  assert_eq(
    @mooncharge.evaluate_timed_charging_profiles([timed], None, 1_500).unwrap().limit,
    16.0,
  )
  assert_eq(
    @mooncharge.evaluate_timed_charging_profiles([timed], None, 2_000),
    Err(@mooncharge.ChargingProfileError::NoActiveProfile),
  )
}

///|
test "daily recurring profiles restart their schedule every day" {
  let base = profile(
    11,
    @mooncharge.ChargingProfilePurpose::TxDefaultProfile,
    1,
    None,
    [period(0, 12.0), period(600, 8.0)],
  )
  let recurring = {
    ..base,
    charging_profile_kind: @mooncharge.ChargingProfileKind::Recurring,
    recurrency_kind: Some(@mooncharge.RecurrencyKind::Daily),
  }
  let timed = timed_profile(recurring, None, 1_000, None)
  let decision = @mooncharge.evaluate_timed_charging_profiles(
    [timed],
    None,
    1_000 + 86_400 + 700,
  ).unwrap()
  assert_eq(decision.limit, 8.0)
}

///|
test "relative profiles use the transaction start and reject missing time" {
  let base = profile(
    12,
    @mooncharge.ChargingProfilePurpose::TxProfile,
    2,
    Some(50),
    [period(0, 20.0)],
  )
  let relative = {
    ..base,
    charging_profile_kind: @mooncharge.ChargingProfileKind::Relative,
  }
  let timed = timed_profile(relative, None, 0, Some(1_000))
  assert_eq(
    @mooncharge.evaluate_timed_charging_profiles([timed], Some(50), 1_200).unwrap().limit,
    20.0,
  )
  assert_eq(
    @mooncharge.evaluate_timed_charging_profiles(
      [timed_profile(relative, None, 0, None)],
      Some(50),
      1_200,
    ),
    Err(
      @mooncharge.ChargingProfileError::RelativeProfileRequiresTransactionStart,
    ),
  )
}

///|
test "timed profile selection replaces equal stack levels with the later profile" {
  let first = timed_profile(
    profile(20, @mooncharge.ChargingProfilePurpose::TxDefaultProfile, 1, None, [
      period(0, 10.0),
    ]),
    None,
    1_000,
    None,
  )
  let second = timed_profile(
    profile(21, @mooncharge.ChargingProfilePurpose::TxDefaultProfile, 1, None, [
      period(0, 25.0),
    ]),
    None,
    1_000,
    None,
  )
  let decision = @mooncharge.evaluate_timed_charging_profiles(
    [first, second],
    None,
    1_100,
  ).unwrap()
  assert_eq(decision.profile_id, 21)
  assert_eq(decision.limit, 25.0)
}

///|
test "timed profiles reject unmapped wire validity and missing recurrency" {
  let mapped_required = {
    ..profile(
      30,
      @mooncharge.ChargingProfilePurpose::TxDefaultProfile,
      1,
      None,
      [period(0, 10.0)],
    ),
    valid_from: Some("2026-11-21T00:00:00Z"),
  }
  assert_eq(
    @mooncharge.evaluate_timed_charging_profiles(
      [timed_profile(mapped_required, None, 1_000, None)],
      None,
      1_100,
    ),
    Err(@mooncharge.ChargingProfileError::UnmappedValidityFrom(30)),
  )
  let recurring_without_kind = {
    ..profile(
      31,
      @mooncharge.ChargingProfilePurpose::TxDefaultProfile,
      1,
      None,
      [period(0, 10.0)],
    ),
    charging_profile_kind: @mooncharge.ChargingProfileKind::Recurring,
  }
  assert_eq(
    @mooncharge.evaluate_timed_charging_profiles(
      [timed_profile(recurring_without_kind, None, 1_000, None)],
      None,
      1_100,
    ),
    Err(@mooncharge.ChargingProfileError::RecurringProfileRequiresRecurrency),
  )
}

///|
test "DC power conversion uses explicit voltage" {
  let model = @mooncharge.ElectricalModel::new(
    @mooncharge.ElectricalSystem::DirectCurrent,
    400.0,
  ).unwrap()
  assert_eq(@mooncharge.amps_to_watts(10.0, model).unwrap(), 4_000.0)
  assert_eq(@mooncharge.watts_to_amps(8_000.0, model).unwrap(), 20.0)
}

///|
test "single-phase conversion applies power factor" {
  let model = @mooncharge.ElectricalModel::new(
    @mooncharge.ElectricalSystem::SinglePhaseAc,
    230.0,
    power_factor=0.5,
  ).unwrap()
  assert_eq(@mooncharge.amps_to_watts(1.0, model).unwrap(), 115.0)
  assert_eq(@mooncharge.watts_to_amps(230.0, model).unwrap(), 2.0)
}

///|
test "three-phase conversion distinguishes line-to-line and line-to-neutral" {
  let line_to_line = @mooncharge.ElectricalModel::new(
    @mooncharge.ElectricalSystem::ThreePhaseLineToLineAc,
    400.0,
    power_factor=0.95,
  ).unwrap()
  let watts = @mooncharge.amps_to_watts(
    16.0,
    line_to_line,
    number_phases=Some(3),
  ).unwrap()
  let expected = 16.0 * 400.0 * 3.0.sqrt() * 0.95
  let difference = if watts > expected {
    watts - expected
  } else {
    expected - watts
  }
  assert_true(difference < 0.000001)
  let line_to_neutral = @mooncharge.ElectricalModel::new(
    @mooncharge.ElectricalSystem::ThreePhaseLineToNeutralAc,
    230.0,
  ).unwrap()
  assert_eq(
    @mooncharge.amps_to_watts(10.0, line_to_neutral, number_phases=Some(3)).unwrap(),
    6_900.0,
  )
}

///|
test "power conversion rejects phase mismatch and normalizes decisions" {
  let model = @mooncharge.ElectricalModel::new(
    @mooncharge.ElectricalSystem::ThreePhaseLineToLineAc,
    400.0,
  ).unwrap()
  assert_eq(
    @mooncharge.amps_to_watts(10.0, model, number_phases=Some(1)),
    Err(@mooncharge.PowerConversionError::PhaseCountMismatch(3, 1)),
  )
  let decision : @mooncharge.ChargingDecision = {
    limit: 10.0,
    unit: @mooncharge.ChargingRateUnit::Amps,
    profile_id: 70,
    capped_by_charge_point_max: false,
    number_phases: Some(3),
  }
  let normalized = @mooncharge.normalize_charging_decision(
    decision,
    @mooncharge.ChargingRateUnit::Watts,
    model,
  ).unwrap()
  assert_eq(normalized.unit, @mooncharge.ChargingRateUnit::Watts)
  assert_true(normalized.limit > 6_900.0)
  assert_eq(normalized.number_phases, Some(3))
}

///|
test "charge point snapshots round-trip all persisted domains idempotently" {
  let station = @mooncharge.ChargePointSession::new([1, 2]).unwrap()
  station.connectors[0] = station.connectors[0]
    .begin_transaction(100, "RFID-1", 5, "2026-11-21T00:00:00Z")
    .unwrap()
    .begin_charging()
    .unwrap()
  let reservations = @mooncharge.ReservationBook::new()
  ignore(
    reservations
    .reserve(
      {
        connector_id: 2,
        expiry_date: "2026-11-21T01:00:00Z",
        id_tag: "RFID-2",
        reservation_id: 200,
        parent_id_tag: None,
      },
      2_000,
    )
    .unwrap(),
  )
  let local_auth = @mooncharge.LocalAuthorizationStore::new()
  local_auth
  .apply({
    list_version: 1,
    update_type: @mooncharge.LocalListUpdateType::Full,
    local_authorization_list: [
      {
        id_tag: "RFID-1",
        id_tag_info: {
          status: @mooncharge.AuthorizationStatus::Accepted,
          expiry_date: None,
          parent_id_tag: None,
        },
      },
    ],
  })
  .unwrap()
  let validity = @mooncharge.EpochInterval::new(100, Some(2_000)).unwrap()
  let timed = timed_profile(
    profile(90, @mooncharge.ChargingProfilePurpose::TxDefaultProfile, 1, None, [
      period(0, 16.0),
    ]),
    Some(validity),
    100,
    None,
  )
  let snapshot = @mooncharge.ChargePointSnapshot::new(
    station,
    reservations,
    local_auth,
    [timed],
  ).unwrap()
  let saved = @mooncharge.save_snapshot(snapshot).unwrap()
  let restored = @mooncharge.load_snapshot(saved).unwrap()
  assert_eq(restored, snapshot)
  assert_eq(@mooncharge.save_snapshot(restored), Ok(saved))
  assert_eq(restored.station.summary().active_transactions, 1)
  assert_eq(restored.reservations.count(), 1)
  assert_eq(restored.local_auth.list_version(), 1)
  assert_eq(restored.timed_profiles.length(), 1)
}

///|
test "legacy v1 snapshots migrate with ignored unknown fields" {
  let restored = @mooncharge.load_snapshot(
    "{\"version\":1,\"future\":true,\"connectors\":[{\"connectorId\":1,\"status\":\"Faulted\",\"future\":1},{\"connectorId\":2,\"status\":\"Available\"}]}",
  ).unwrap()
  assert_eq(restored.station.station_mode, @mooncharge.StationMode::Operative)
  assert_eq(restored.station.connectors.length(), 2)
  assert_eq(
    restored.station.connectors[0].status,
    @mooncharge.ChargePointStatus::Faulted,
  )
  assert_eq(restored.reservations.count(), 0)
  assert_eq(restored.local_auth.list_version(), 0)
  assert_eq(restored.timed_profiles.length(), 0)
}

///|
test "snapshot loader rejects malformed duplicate and unsupported documents" {
  assert_eq(
    @mooncharge.load_snapshot("{"),
    Err(@mooncharge.SnapshotError::InvalidJson),
  )
  assert_eq(
    @mooncharge.load_snapshot(
      "{\"schemaVersion\":2,\"station\":{\"mode\":\"Operative\",\"mode\":\"Inoperative\",\"connectors\":[]},\"reservations\":[],\"localAuth\":{\"version\":0,\"entries\":[]},\"timedProfiles\":[]}",
    ),
    Err(@mooncharge.SnapshotError::InvalidJson),
  )
  assert_eq(
    @mooncharge.load_snapshot(
      "{\"schemaVersion\":99,\"station\":{},\"reservations\":[],\"localAuth\":{},\"timedProfiles\":[]}",
    ),
    Err(@mooncharge.SnapshotError::UnsupportedSchemaVersion(99)),
  )
}
