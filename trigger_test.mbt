///|
fn frame_payload(text : String) -> Json raise {
  match @mooncharge.parse_frame(text) {
    Ok(@mooncharge.Call(_, _, payload)) => payload
    Ok(@mooncharge.CallResult(_, payload)) => payload
    _ => fail("expected a frame with an object payload")
  }
}

///|
test "TriggerMessage accepts the standard request set and optional connector" {
  let request = match
    @mooncharge.TriggerMessageRequest::from_json(
      frame_payload(
        "[2,\"trigger-1\",\"TriggerMessage\",{\"requestedMessage\":\"MeterValues\",\"connectorId\":2}]",
      ),
    ) {
    Ok(request) => request
    Err(_) => fail("failed to parse TriggerMessage")
  }
  assert_eq(
    request.requested_message,
    @mooncharge.TriggerMessageName::MeterValues,
  )
  assert_eq(request.connector_id, Some(2))
  assert_eq(
    @mooncharge.TriggerMessageRequest::from_json(request.to_json()),
    Ok(request),
  )
  assert_eq(
    @mooncharge.TriggerMessageRequest::from_json(
      frame_payload(
        "[2,\"trigger-bad\",\"TriggerMessage\",{\"requestedMessage\":\"Unknown\"}]",
      ),
    ),
    Err(
      @mooncharge.ProtocolError::UnsupportedValue("requestedMessage", "Unknown"),
    ),
  )
}

///|
test "trigger confirmations are strict about status values" {
  assert_eq(
    @mooncharge.TriggerMessageResponse::from_json(
      frame_payload("[3,\"trigger-1\",{\"status\":\"Accepted\"}]"),
    ),
    Ok({ status: @mooncharge.TriggerMessageStatus::Accepted, }),
  )
  assert_eq(
    @mooncharge.TriggerMessageResponse::from_json(
      frame_payload("[3,\"trigger-2\",{\"status\":\"Unsupported\"}]"),
    ),
    Err(@mooncharge.ProtocolError::UnsupportedValue("status", "Unsupported")),
  )
}

///|
test "ExtendedTriggerMessage supports certificate signing requests" {
  let request = match
    @mooncharge.ExtendedTriggerMessageRequest::from_json(
      frame_payload(
        "[2,\"ext-trigger\",\"ExtendedTriggerMessage\",{\"requestedMessage\":\"SignChargePointCertificate\"}]",
      ),
    ) {
    Ok(request) => request
    Err(_) => fail("failed to parse ExtendedTriggerMessage")
  }
  assert_eq(
    request.requested_message,
    @mooncharge.ExtendedTriggerMessageName::SignChargePointCertificate,
  )
  assert_eq(request.connector_id, None)
  assert_eq(
    @mooncharge.ExtendedTriggerMessageRequest::from_json(request.to_json()),
    Ok(request),
  )
  assert_eq(
    @mooncharge.ExtendedTriggerMessageResponse::from_json(
      frame_payload("[3,\"ext-trigger\",{\"status\":\"NotImplemented\"}]"),
    ),
    Ok({ status: @mooncharge.TriggerMessageStatus::NotImplemented, }),
  )
}

///|
test "GetCompositeSchedule round-trips its request and charging schedule" {
  let request = match
    @mooncharge.GetCompositeScheduleRequest::from_json(
      frame_payload(
        "[2,\"schedule-1\",\"GetCompositeSchedule\",{\"connectorId\":1,\"duration\":900,\"chargingRateUnit\":\"W\"}]",
      ),
    ) {
    Ok(request) => request
    Err(_) => fail("failed to parse GetCompositeSchedule")
  }
  assert_eq(request.connector_id, 1)
  assert_eq(request.duration, 900)
  assert_eq(
    request.charging_rate_unit,
    Some(@mooncharge.ChargingRateUnit::Watts),
  )
  assert_eq(
    @mooncharge.GetCompositeScheduleRequest::from_json(request.to_json()),
    Ok(request),
  )
  let response = match
    @mooncharge.GetCompositeScheduleResponse::from_json(
      frame_payload(
        "[3,\"schedule-1\",{\"status\":\"Accepted\",\"connectorId\":1,\"schedule\":{\"duration\":900,\"chargingRateUnit\":\"W\",\"chargingSchedulePeriod\":[{\"startPeriod\":0,\"limit\":11000},{\"startPeriod\":600,\"limit\":7000}]}}]",
      ),
    ) {
    Ok(response) => response
    Err(_) => fail("failed to parse composite schedule response")
  }
  assert_eq(response.status, @mooncharge.GetCompositeScheduleStatus::Accepted)
  assert_eq(response.connector_id, Some(1))
  let schedule = match response.schedule {
    Some(schedule) => schedule
    None => fail("expected a composite schedule")
  }
  assert_eq(schedule.duration, Some(900))
  assert_eq(schedule.periods.length(), 2)
  assert_eq(
    @mooncharge.GetCompositeScheduleResponse::from_json(response.to_json()),
    Ok(response),
  )
}

///|
test "GetCompositeSchedule rejects zero duration and invalid units" {
  assert_eq(
    @mooncharge.GetCompositeScheduleRequest::from_json(
      frame_payload(
        "[2,\"schedule-bad\",\"GetCompositeSchedule\",{\"connectorId\":1,\"duration\":0}]",
      ),
    ),
    Err(@mooncharge.ProtocolError::InvalidField("duration")),
  )
  assert_eq(
    @mooncharge.GetCompositeScheduleRequest::from_json(
      frame_payload(
        "[2,\"schedule-bad\",\"GetCompositeSchedule\",{\"connectorId\":1,\"duration\":60,\"chargingRateUnit\":\"kW\"}]",
      ),
    ),
    Err(@mooncharge.ProtocolError::UnsupportedValue("chargingRateUnit", "kW")),
  )
}

///|
test "trigger and schedule requests dispatch with typed payloads" {
  let trigger = match
    @mooncharge.parse_frame(
      "[2,\"trigger-dispatch\",\"TriggerMessage\",{\"requestedMessage\":\"Heartbeat\"}]",
    ) {
    Ok(frame) => frame
    Err(_) => fail("failed to parse trigger frame")
  }
  match
    @mooncharge.dispatch_call(
      trigger,
      @mooncharge.MessageDirection::CentralSystemToChargePoint,
    ) {
    Ok(@mooncharge.TypedCall::TriggerMessage(request)) =>
      assert_eq(
        request.requested_message,
        @mooncharge.TriggerMessageName::Heartbeat,
      )
    _ => fail("expected typed TriggerMessage")
  }
  let schedule = match
    @mooncharge.parse_frame(
      "[2,\"schedule-dispatch\",\"GetCompositeSchedule\",{\"connectorId\":1,\"duration\":600}]",
    ) {
    Ok(frame) => frame
    Err(_) => fail("failed to parse schedule frame")
  }
  match
    @mooncharge.dispatch_call(
      schedule,
      @mooncharge.MessageDirection::CentralSystemToChargePoint,
    ) {
    Ok(@mooncharge.TypedCall::GetCompositeSchedule(request)) =>
      assert_eq(request.duration, 600)
    _ => fail("expected typed GetCompositeSchedule")
  }
}
