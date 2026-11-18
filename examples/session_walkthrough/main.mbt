///|
fn main raise {
  let available = match @mooncharge.ConnectorSession::new(1) {
    Ok(value) => value
    Err(_) => fail("connector 1 is invalid")
  }
  let preparing = match
    available.begin_transaction(1001, "RFID-DEMO", 5000, "2026-11-18T08:00:00Z") {
    Ok(value) => value
    Err(_) => fail("transaction did not start")
  }
  let charging = match preparing.begin_charging() {
    Ok(value) => value
    Err(_) => fail("charging did not start")
  }
  let finishing = match
    charging.finish_transaction(
      1001,
      12500,
      "2026-11-18T09:00:00Z",
      Some(@mooncharge.StopReason::Local),
    ) {
    Ok(value) => value
    Err(_) => fail("transaction did not stop")
  }
  let delivered = match finishing.transaction {
    Some(transaction) =>
      match transaction.meter_stop {
        Some(stop) => stop - transaction.meter_start
        None => 0
      }
    None => 0
  }
  println("status=\{finishing.status.name()} delivered_wh=\{delivered}")
}
