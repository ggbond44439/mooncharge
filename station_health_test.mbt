///|
fn health_policy() -> @mooncharge.HealthPolicy {
  @mooncharge.HealthPolicy::new(30_000, 3, 1).unwrap()
}

///|
test "healthy station reports full score without attention issues" {
  let station = @mooncharge.ChargePointSession::new([1, 2]).unwrap()
  station.connectors[0] = station.connectors[0]
    .begin_transaction(7, "RFID-1", 0, "2026-11-22T00:00:00Z")
    .unwrap()
    .begin_charging()
    .unwrap()
  let input = @mooncharge.HealthCheckInput::new(
    @mooncharge.ConnectivityStatus::Online,
    0,
    Some(1_000),
    0,
  ).unwrap()
  let report = @mooncharge.evaluate_station_health(
    station,
    input,
    health_policy(),
  )
  assert_eq(report.level, @mooncharge.HealthLevel::Healthy)
  assert_eq(report.score, 100)
  assert_eq(report.issues, [])
  assert_false(report.requires_attention())
  assert_eq(report.summary.active_transactions, 1)
}

///|
test "reconnecting stale heartbeats and alarms degrade health" {
  let station = @mooncharge.ChargePointSession::new([1, 2]).unwrap()
  let input = @mooncharge.HealthCheckInput::new(
    @mooncharge.ConnectivityStatus::Reconnecting,
    2,
    Some(45_000),
    1,
  ).unwrap()
  let report = @mooncharge.evaluate_station_health(
    station,
    input,
    health_policy(),
  )
  assert_eq(report.level, @mooncharge.HealthLevel::Degraded)
  assert_eq(report.issues, [
    @mooncharge.HealthIssue::Reconnecting,
    @mooncharge.HealthIssue::HeartbeatStale(45_000, 30_000),
    @mooncharge.HealthIssue::ActiveAlarms(1, 1),
  ])
  assert_true(report.score <= 79)
  assert_true(report.requires_attention())
}

///|
test "offline faults and excessive alarms are critical" {
  let station = @mooncharge.ChargePointSession::new([1, 2]).unwrap()
  station
  .apply_status_batch([
    { connector_id: 1, status: @mooncharge.ChargePointStatus::Faulted, },
    { connector_id: 2, status: @mooncharge.ChargePointStatus::Available, },
  ])
  .unwrap()
  let input = @mooncharge.HealthCheckInput::new(
    @mooncharge.ConnectivityStatus::Offline,
    0,
    Some(60_000),
    2,
  ).unwrap()
  let report = @mooncharge.evaluate_station_health(
    station,
    input,
    health_policy(),
  )
  assert_eq(report.level, @mooncharge.HealthLevel::Critical)
  assert_eq(report.issues, [
    @mooncharge.HealthIssue::Disconnected,
    @mooncharge.HealthIssue::HeartbeatStale(60_000, 30_000),
    @mooncharge.HealthIssue::ActiveAlarms(2, 1),
    @mooncharge.HealthIssue::FaultedConnectors(1),
  ])
  assert_true(report.score <= 39)
}

///|
test "inoperative all-unavailable station is degraded" {
  let station = @mooncharge.ChargePointSession::new([1, 2]).unwrap()
  station
  .change_availability(0, @mooncharge.AvailabilityType::Inoperative)
  .unwrap()
  let input = @mooncharge.HealthCheckInput::new(
    @mooncharge.ConnectivityStatus::Online,
    0,
    Some(100),
    0,
  ).unwrap()
  let report = @mooncharge.evaluate_station_health(
    station,
    input,
    health_policy(),
  )
  assert_eq(report.level, @mooncharge.HealthLevel::Degraded)
  assert_eq(report.issues, [
    @mooncharge.HealthIssue::StationInoperative,
    @mooncharge.HealthIssue::AllConnectorsUnavailable,
  ])
}

///|
test "health policy and input constructors reject invalid values" {
  assert_eq(
    @mooncharge.HealthPolicy::new(0, 1, 1),
    Err(@mooncharge.HealthError::InvalidStaleHeartbeat(0)),
  )
  assert_eq(
    @mooncharge.HealthPolicy::new(1_000, -1, 1),
    Err(@mooncharge.HealthError::InvalidMaxReconnectAttempts(-1)),
  )
  assert_eq(
    @mooncharge.HealthCheckInput::new(
      @mooncharge.ConnectivityStatus::Online,
      -1,
      None,
      0,
    ),
    Err(@mooncharge.HealthError::InvalidReconnectAttempt(-1)),
  )
  assert_eq(
    @mooncharge.HealthCheckInput::new(
      @mooncharge.ConnectivityStatus::Online,
      0,
      Some(-1),
      0,
    ),
    Err(@mooncharge.HealthError::InvalidHeartbeatAge(-1)),
  )
  assert_eq(
    @mooncharge.HealthCheckInput::new(
      @mooncharge.ConnectivityStatus::Online,
      0,
      None,
      -1,
    ),
    Err(@mooncharge.HealthError::InvalidActiveAlarms(-1)),
  )
}

///|
test "transport states map directly into health connectivity" {
  let policy = @mooncharge.ReconnectPolicy::new(100, 1_000).unwrap()
  let transport = @mooncharge.OcppTransport::new(
    @mooncharge.OcppVersion::V16J,
    2,
    policy,
  ).unwrap()
  let offline = @mooncharge.HealthCheckInput::from_transport(transport, None, 0).unwrap()
  assert_eq(offline.connectivity, @mooncharge.ConnectivityStatus::Offline)
  ignore(transport.handle(@mooncharge.TransportEvent::Open))
  let connecting = @mooncharge.HealthCheckInput::from_transport(
    transport,
    None,
    0,
  ).unwrap()
  assert_eq(
    connecting.connectivity,
    @mooncharge.ConnectivityStatus::Reconnecting,
  )
  ignore(transport.handle(@mooncharge.TransportEvent::Opened))
  let online = @mooncharge.HealthCheckInput::from_transport(
    transport,
    Some(10),
    0,
  ).unwrap()
  assert_eq(online.connectivity, @mooncharge.ConnectivityStatus::Online)
}
