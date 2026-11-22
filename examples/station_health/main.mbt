///|
fn level_name(value : @mooncharge.HealthLevel) -> String {
  match value {
    @mooncharge.HealthLevel::Healthy => "Healthy"
    @mooncharge.HealthLevel::Degraded => "Degraded"
    @mooncharge.HealthLevel::Critical => "Critical"
  }
}

///|
fn main raise {
  let policy = match @mooncharge.HealthPolicy::new(30_000, 3, 1) {
    Ok(policy) => policy
    Err(_) => fail("failed to create health policy")
  }
  let online = match
    @mooncharge.HealthCheckInput::new(
      @mooncharge.ConnectivityStatus::Online,
      0,
      Some(1_000),
      0,
    ) {
    Ok(input) => input
    Err(_) => fail("failed to create online health input")
  }
  let station = match @mooncharge.ChargePointSession::new([1, 2, 3]) {
    Ok(station) => station
    Err(_) => fail("failed to create station")
  }
  let healthy = @mooncharge.evaluate_station_health(station, online, policy)
  println(
    "healthy=\{level_name(healthy.level)} score=\{healthy.score} attention=\{healthy.requires_attention()}",
  )
  match
    station.apply_status_batch([
      { connector_id: 1, status: @mooncharge.ChargePointStatus::Faulted, },
    ]) {
    Ok(_) => ()
    Err(_) => fail("failed to mark connector fault")
  }
  let degraded_input = match
    @mooncharge.HealthCheckInput::new(
      @mooncharge.ConnectivityStatus::Reconnecting,
      4,
      Some(45_000),
      2,
    ) {
    Ok(input) => input
    Err(_) => fail("failed to create degraded health input")
  }
  let critical = @mooncharge.evaluate_station_health(
    station, degraded_input, policy,
  )
  println(
    "critical=\{level_name(critical.level)} score=\{critical.score} issues=\{critical.issues.length()} faulted=\{critical.summary.faulted}",
  )
}
