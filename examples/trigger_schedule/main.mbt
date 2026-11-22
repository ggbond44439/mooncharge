///|
fn payload(text : String) -> Json raise {
  match @mooncharge.parse_frame(text) {
    Ok(@mooncharge.Call(_, _, value)) | Ok(@mooncharge.CallResult(_, value)) =>
      value
    _ => fail("expected a JSON-RPC frame")
  }
}

///|
fn trigger_name(value : @mooncharge.TriggerMessageName) -> String {
  match value {
    @mooncharge.TriggerMessageName::BootNotification => "BootNotification"
    @mooncharge.TriggerMessageName::DiagnosticsStatusNotification =>
      "DiagnosticsStatusNotification"
    @mooncharge.TriggerMessageName::FirmwareStatusNotification =>
      "FirmwareStatusNotification"
    @mooncharge.TriggerMessageName::Heartbeat => "Heartbeat"
    @mooncharge.TriggerMessageName::MeterValues => "MeterValues"
    @mooncharge.TriggerMessageName::StatusNotification => "StatusNotification"
  }
}

///|
fn schedule_status(value : @mooncharge.GetCompositeScheduleStatus) -> String {
  match value {
    @mooncharge.GetCompositeScheduleStatus::Accepted => "Accepted"
    @mooncharge.GetCompositeScheduleStatus::Rejected => "Rejected"
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
  let trigger = match
    @mooncharge.TriggerMessageRequest::from_json(
      payload(
        "[2,\"trigger-1\",\"TriggerMessage\",{\"requestedMessage\":\"MeterValues\",\"connectorId\":2}]",
      ),
    ) {
    Ok(request) => request
    Err(_) => fail("failed to parse trigger request")
  }
  println(
    "trigger=\{trigger_name(trigger.requested_message)} connector=\{option_int(trigger.connector_id)}",
  )
  let request = match
    @mooncharge.GetCompositeScheduleRequest::from_json(
      payload(
        "[2,\"schedule-1\",\"GetCompositeSchedule\",{\"connectorId\":1,\"duration\":900,\"chargingRateUnit\":\"W\"}]",
      ),
    ) {
    Ok(request) => request
    Err(_) => fail("failed to parse composite schedule request")
  }
  let response = match
    @mooncharge.GetCompositeScheduleResponse::from_json(
      payload(
        "[3,\"schedule-1\",{\"status\":\"Accepted\",\"connectorId\":1,\"schedule\":{\"duration\":900,\"chargingRateUnit\":\"W\",\"chargingSchedulePeriod\":[{\"startPeriod\":0,\"limit\":11000},{\"startPeriod\":600,\"limit\":7000}]}}]",
      ),
    ) {
    Ok(response) => response
    Err(_) => fail("failed to parse composite schedule")
  }
  let periods = match response.schedule {
    Some(schedule) => schedule.periods.length()
    None => 0
  }
  println(
    "schedule_connector=\{request.connector_id} duration=\{request.duration} status=\{schedule_status(response.status)} periods=\{periods}",
  )
}
