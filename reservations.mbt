///|
#derive(Eq, @debug.Debug)
pub(all) enum ReservationStatus {
  Accepted
  Faulted
  Occupied
  Rejected
  Unavailable
}

///|
fn parse_reservation_status(
  value : String,
) -> ReservationStatus raise ProtocolFailure {
  match value {
    "Accepted" => Accepted
    "Faulted" => Faulted
    "Occupied" => Occupied
    "Rejected" => Rejected
    "Unavailable" => Unavailable
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
fn reservation_status_name(value : ReservationStatus) -> String {
  match value {
    Accepted => "Accepted"
    Faulted => "Faulted"
    Occupied => "Occupied"
    Rejected => "Rejected"
    Unavailable => "Unavailable"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ReserveNowRequest {
  connector_id : Int32
  expiry_date : String
  id_tag : String
  reservation_id : Int32
  parent_id_tag : String?
}

///|
fn parse_reserve_now(value : Json) -> ReserveNowRequest raise ProtocolFailure {
  let id_tag = required_string(value, "idTag")
  if id_tag.is_empty() {
    refuse(InvalidField("idTag"))
  }
  {
    connector_id: required_nonnegative_int(value, "connectorId"),
    expiry_date: required_string(value, "expiryDate"),
    id_tag,
    reservation_id: required_nonnegative_int(value, "reservationId"),
    parent_id_tag: optional_string(value, "parentIdTag"),
  }
}

///|
pub fn ReserveNowRequest::from_json(
  value : Json,
) -> Result[ReserveNowRequest, ProtocolError] {
  result_of(() => parse_reserve_now(value))
}

///|
pub fn ReserveNowRequest::to_json(self : ReserveNowRequest) -> Json {
  let fields : Map[String, Json] = {
    "connectorId": int_json(self.connector_id),
    "expiryDate": Json::string(self.expiry_date),
    "idTag": Json::string(self.id_tag),
    "reservationId": int_json(self.reservation_id),
  }
  set_optional_string(fields, "parentIdTag", self.parent_id_tag)
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ReserveNowResponse {
  status : ReservationStatus
}

///|
fn parse_reserve_now_response(
  value : Json,
) -> ReserveNowResponse raise ProtocolFailure {
  { status: parse_reservation_status(required_string(value, "status")), }
}

///|
pub fn ReserveNowResponse::from_json(
  value : Json,
) -> Result[ReserveNowResponse, ProtocolError] {
  result_of(() => parse_reserve_now_response(value))
}

///|
pub fn ReserveNowResponse::to_json(self : ReserveNowResponse) -> Json {
  Json::object({ "status": Json::string(reservation_status_name(self.status)) })
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct Reservation {
  reservation_id : Int32
  connector_id : Int32
  id_tag : String
  expires_at : Int64
  parent_id_tag : String?
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum ReservationError {
  InvalidExpiry(Int64)
  DuplicateReservationId(Int32)
  ConnectorAlreadyReserved(Int32)
  ReservationNotFound(Int32)
  ConnectorMismatch(Int32, Int32)
  IdTagMismatch(String, String)
  ExpiredReservation(Int32)
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ReservationBook {
  mut reservations : Array[Reservation]
}

///|
pub fn ReservationBook::new() -> ReservationBook {
  { reservations: [], }
}

///|
fn reservation_index(book : ReservationBook, reservation_id : Int32) -> Int32? {
  for index in 0..<book.reservations.length() {
    if book.reservations[index].reservation_id == reservation_id {
      return Some(index)
    }
  }
  None
}

///|
pub fn ReservationBook::reserve(
  self : ReservationBook,
  request : ReserveNowRequest,
  expires_at : Int64,
) -> Result[Reservation, ReservationError] {
  if expires_at <= 0 {
    return Err(InvalidExpiry(expires_at))
  }
  if reservation_index(self, request.reservation_id) is Some(_) {
    return Err(DuplicateReservationId(request.reservation_id))
  }
  for reservation in self.reservations {
    if reservation.connector_id == request.connector_id {
      return Err(ConnectorAlreadyReserved(request.connector_id))
    }
  }
  let reservation = {
    reservation_id: request.reservation_id,
    connector_id: request.connector_id,
    id_tag: request.id_tag,
    expires_at,
    parent_id_tag: request.parent_id_tag,
  }
  self.reservations.push(reservation)
  Ok(reservation)
}

///|
pub fn ReservationBook::cancel(
  self : ReservationBook,
  reservation_id : Int32,
) -> Result[Reservation, ReservationError] {
  let index = match reservation_index(self, reservation_id) {
    Some(index) => index
    None => return Err(ReservationNotFound(reservation_id))
  }
  Ok(self.reservations.remove(index))
}

///|
pub fn ReservationBook::expire(
  self : ReservationBook,
  now : Int64,
) -> Array[Reservation] {
  let expired : Array[Reservation] = []
  let remaining : Array[Reservation] = []
  for reservation in self.reservations {
    if now >= reservation.expires_at {
      expired.push(reservation)
    } else {
      remaining.push(reservation)
    }
  }
  self.reservations = remaining
  expired
}

///|
pub fn ReservationBook::claim(
  self : ReservationBook,
  connector_id : Int32,
  id_tag : String,
  reservation_id : Int32?,
  now : Int64,
) -> Result[Reservation, ReservationError] {
  let index = match reservation_id {
    Some(reservation_id) =>
      match reservation_index(self, reservation_id) {
        Some(index) => index
        None => return Err(ReservationNotFound(reservation_id))
      }
    None => {
      let mut found : Int32? = None
      for index in 0..<self.reservations.length() {
        let reservation = self.reservations[index]
        if reservation.connector_id == connector_id {
          found = Some(index)
        }
      }
      match found {
        Some(index) => index
        None => return Err(ReservationNotFound(0))
      }
    }
  }
  let reservation = self.reservations[index]
  if reservation.connector_id != connector_id {
    return Err(ConnectorMismatch(reservation.connector_id, connector_id))
  }
  if reservation.id_tag != id_tag {
    return Err(IdTagMismatch(reservation.id_tag, id_tag))
  }
  if now >= reservation.expires_at {
    ignore(self.reservations.remove(index))
    return Err(ExpiredReservation(reservation.reservation_id))
  }
  Ok(self.reservations.remove(index))
}

///|
pub fn ReservationBook::count(self : ReservationBook) -> Int32 {
  self.reservations.length()
}
