///|
fn main raise {
  let station = match @mooncharge.ChargePointSession::new([1, 2]) {
    Ok(station) => station
    Err(_) => fail("failed to create station")
  }
  station.connectors[0] = station.connectors[0]
    .begin_transaction(10, "RFID-1", 0, "2026-11-21T00:00:00Z")
    .unwrap()
    .begin_charging()
    .unwrap()
  let reservations = @mooncharge.ReservationBook::new()
  match
    reservations.reserve(
      {
        connector_id: 2,
        expiry_date: "2026-11-21T01:00:00Z",
        id_tag: "RFID-2",
        reservation_id: 20,
        parent_id_tag: None,
      },
      2_000,
    ) {
    Ok(_) => ()
    Err(_) => fail("failed to reserve connector")
  }
  let local_auth = @mooncharge.LocalAuthorizationStore::new()
  match
    local_auth.apply({
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
    }) {
    Ok(_) => ()
    Err(_) => fail("failed to apply local authorization")
  }
  let snapshot = match
    @mooncharge.ChargePointSnapshot::new(station, reservations, local_auth, []) {
    Ok(snapshot) => snapshot
    Err(_) => fail("snapshot validation failed")
  }
  let text = match @mooncharge.save_snapshot(snapshot) {
    Ok(text) => text
    Err(_) => fail("failed to save snapshot")
  }
  let restored = match @mooncharge.load_snapshot(text) {
    Ok(restored) => restored
    Err(_) => fail("failed to restore snapshot")
  }
  println(
    "connectors=\{restored.station.connectors.length()} active=\{restored.station.summary().active_transactions} reservations=\{restored.reservations.count()} local_version=\{restored.local_auth.list_version()} stable=\{restored == snapshot}",
  )
}
