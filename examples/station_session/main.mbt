///|
fn main raise {
  let station = match @mooncharge.ChargePointSession::new([1, 2, 3]) {
    Ok(station) => station
    Err(_) => fail("failed to create station")
  }
  match
    station.apply_status_batch([
      { connector_id: 1, status: @mooncharge.ChargePointStatus::Preparing, },
      { connector_id: 2, status: @mooncharge.ChargePointStatus::Unavailable, },
    ]) {
    Ok(_) => ()
    Err(_) => fail("failed to apply connector statuses")
  }
  match
    station.change_availability(3, @mooncharge.AvailabilityType::Inoperative) {
    Ok(_) => ()
    Err(_) => fail("failed to change connector availability")
  }
  let summary = station.summary()
  let mode = match summary.station_mode {
    @mooncharge.StationMode::Operative => "Operative"
    @mooncharge.StationMode::Inoperative => "Inoperative"
  }
  println(
    "mode=\{mode} connectors=\{summary.total_connectors} available=\{summary.available} unavailable=\{summary.unavailable} consistent=\{station.is_consistent()}",
  )
}
