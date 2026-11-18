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
