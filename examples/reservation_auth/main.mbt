///|
fn main raise {
  let reserve_payload = match
    @mooncharge.parse_frame(
      "[2,\"reserve\",\"ReserveNow\",{\"connectorId\":1,\"expiryDate\":\"2026-11-21T01:00:00Z\",\"idTag\":\"RFID-R\",\"reservationId\":22}]",
    ) {
    Ok(@mooncharge.Call(_, _, payload)) => payload
    _ => fail("expected ReserveNow CALL")
  }
  let request = match
    @mooncharge.ReserveNowRequest::from_json(reserve_payload) {
    Ok(request) => request
    Err(error) => fail(error.message())
  }
  let book = @mooncharge.ReservationBook::new()
  match book.reserve(request, 1_000) {
    Ok(_) => ()
    Err(_) => fail("failed to reserve connector")
  }
  let list_payload = match
    @mooncharge.parse_frame(
      "[2,\"list\",\"SendLocalList\",{\"listVersion\":1,\"updateType\":\"Full\",\"localAuthorizationList\":[{\"idTag\":\"RFID-R\",\"idTagInfo\":{\"status\":\"Accepted\"}}]}]",
    ) {
    Ok(@mooncharge.Call(_, _, payload)) => payload
    _ => fail("expected SendLocalList CALL")
  }
  let list = match @mooncharge.SendLocalListRequest::from_json(list_payload) {
    Ok(list) => list
    Err(error) => fail(error.message())
  }
  let auth = @mooncharge.LocalAuthorizationStore::new()
  match auth.apply(list) {
    Ok(_) => ()
    Err(_) => fail("failed to apply local authorization list")
  }
  let claimed = match book.claim(1, "RFID-R", Some(22), 100) {
    Ok(reservation) => reservation
    Err(_) => fail("failed to claim reservation")
  }
  let status = match auth.authorize("RFID-R") {
    Some(info) =>
      match info.status {
        @mooncharge.AuthorizationStatus::Accepted => "Accepted"
        _ => "Rejected"
      }
    None => "Missing"
  }
  println(
    "reservation=\{claimed.reservation_id} connector=\{claimed.connector_id} auth=\{status} version=\{auth.list_version()}",
  )
}
