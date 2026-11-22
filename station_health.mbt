///|
#derive(Eq, @debug.Debug)
pub(all) enum ConnectivityStatus {
  Online
  Reconnecting
  Offline
}

///|
pub fn ConnectivityStatus::from_transport(
  state : TransportState,
) -> ConnectivityStatus {
  match state {
    Connected => Online
    Connecting | Reconnecting => Reconnecting
    Disconnected | Closed => Offline
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct HealthPolicy {
  stale_heartbeat_ms : Int64
  max_reconnect_attempts : Int32
  max_active_alarms : Int32
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum HealthError {
  InvalidStaleHeartbeat(Int64)
  InvalidMaxReconnectAttempts(Int32)
  InvalidMaxActiveAlarms(Int32)
  InvalidReconnectAttempt(Int32)
  InvalidHeartbeatAge(Int64)
  InvalidActiveAlarms(Int32)
}

///|
pub fn HealthPolicy::new(
  stale_heartbeat_ms : Int64,
  max_reconnect_attempts : Int32,
  max_active_alarms : Int32,
) -> Result[HealthPolicy, HealthError] {
  if stale_heartbeat_ms <= 0 {
    return Err(InvalidStaleHeartbeat(stale_heartbeat_ms))
  }
  if max_reconnect_attempts < 0 {
    return Err(InvalidMaxReconnectAttempts(max_reconnect_attempts))
  }
  if max_active_alarms < 0 {
    return Err(InvalidMaxActiveAlarms(max_active_alarms))
  }
  Ok({ stale_heartbeat_ms, max_reconnect_attempts, max_active_alarms, })
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct HealthCheckInput {
  connectivity : ConnectivityStatus
  reconnect_attempt : Int32
  last_heartbeat_age_ms : Int64?
  active_alarms : Int32
}

///|
pub fn HealthCheckInput::new(
  connectivity : ConnectivityStatus,
  reconnect_attempt : Int32,
  last_heartbeat_age_ms : Int64?,
  active_alarms : Int32,
) -> Result[HealthCheckInput, HealthError] {
  if reconnect_attempt < 0 {
    return Err(InvalidReconnectAttempt(reconnect_attempt))
  }
  match last_heartbeat_age_ms {
    Some(age) if age < 0 => return Err(InvalidHeartbeatAge(age))
    _ => ()
  }
  if active_alarms < 0 {
    return Err(InvalidActiveAlarms(active_alarms))
  }
  Ok({ connectivity, reconnect_attempt, last_heartbeat_age_ms, active_alarms, })
}

///|
pub fn HealthCheckInput::from_transport(
  transport : OcppTransport,
  last_heartbeat_age_ms : Int64?,
  active_alarms : Int32,
) -> Result[HealthCheckInput, HealthError] {
  HealthCheckInput::new(
    ConnectivityStatus::from_transport(transport.state()),
    transport.reconnect_attempt(),
    last_heartbeat_age_ms,
    active_alarms,
  )
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum HealthLevel {
  Healthy
  Degraded
  Critical
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum HealthIssue {
  Disconnected
  Reconnecting
  ReconnectAttemptsExceeded(Int32, Int32)
  HeartbeatStale(Int64, Int64)
  MissingHeartbeat
  FaultedConnectors(Int32)
  InconsistentStation(Int32)
  ActiveAlarms(Int32, Int32)
  StationInoperative
  AllConnectorsUnavailable
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct StationHealthReport {
  level : HealthLevel
  score : Int32
  summary : StationSummary
  issues : Array[HealthIssue]
}

///|
pub fn StationHealthReport::requires_attention(
  self : StationHealthReport,
) -> Bool {
  self.level != Healthy
}

///|
fn health_penalty(score : Int32, penalty : Int32) -> Int32 {
  let next = score - penalty
  if next < 0 {
    0
  } else {
    next
  }
}

///|
pub fn evaluate_station_health(
  station : ChargePointSession,
  input : HealthCheckInput,
  policy : HealthPolicy,
) -> StationHealthReport {
  let summary = station.summary()
  let issues : Array[HealthIssue] = []
  let mut score = 100
  let mut critical = false
  let mut degraded = false
  match input.connectivity {
    Offline => {
      issues.push(Disconnected)
      score = health_penalty(score, 70)
      critical = true
    }
    Reconnecting => {
      issues.push(Reconnecting)
      score = health_penalty(score, 25)
      degraded = true
      if input.reconnect_attempt > policy.max_reconnect_attempts {
        issues.push(
          ReconnectAttemptsExceeded(
            input.reconnect_attempt,
            policy.max_reconnect_attempts,
          ),
        )
        score = health_penalty(score, 20)
        critical = true
      }
    }
    Online => ()
  }
  match input.last_heartbeat_age_ms {
    None => {
      issues.push(MissingHeartbeat)
      score = health_penalty(score, 10)
      degraded = true
    }
    Some(age) =>
      if age > policy.stale_heartbeat_ms {
        issues.push(HeartbeatStale(age, policy.stale_heartbeat_ms))
        score = health_penalty(score, 20)
        degraded = true
      }
  }
  if input.active_alarms > 0 {
    issues.push(ActiveAlarms(input.active_alarms, policy.max_active_alarms))
    score = health_penalty(score, input.active_alarms * 10)
    if input.active_alarms > policy.max_active_alarms {
      critical = true
    } else {
      degraded = true
    }
  }
  if summary.faulted > 0 {
    issues.push(FaultedConnectors(summary.faulted))
    score = health_penalty(score, summary.faulted * 20)
    critical = true
  }
  let consistency_issues = station.consistency_issues().length()
  if consistency_issues > 0 {
    issues.push(InconsistentStation(consistency_issues))
    score = health_penalty(score, consistency_issues * 30)
    critical = true
  }
  if summary.station_mode == Inoperative {
    issues.push(StationInoperative)
    score = health_penalty(score, 15)
    degraded = true
  }
  if summary.total_connectors > 0 &&
    summary.available == 0 &&
    summary.charging == 0 &&
    summary.active_transactions == 0 {
    issues.push(AllConnectorsUnavailable)
    score = health_penalty(score, 20)
    degraded = true
  }
  let level = if critical {
    Critical
  } else if degraded || !issues.is_empty() {
    Degraded
  } else {
    Healthy
  }
  let score = match level {
    Healthy => score
    Degraded => if score > 79 { 79 } else { score }
    Critical => if score > 39 { 39 } else { score }
  }
  { level, score, summary, issues, }
}
