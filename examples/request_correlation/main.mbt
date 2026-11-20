///|
fn main raise {
  let table = match
    @mooncharge.PendingCallTable::new(@mooncharge.OcppVersion::V16J, 4) {
    Ok(table) => table
    Err(_) => fail("failed to create pending-call table")
  }
  match
    table.insert(
      @mooncharge.MessageId::Text("start-1"),
      "StartTransaction",
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
      1_000,
    ) {
    Ok(_) => ()
    Err(_) => fail("failed to register pending call")
  }
  let response = match
    @mooncharge.parse_frame(
      "[3,\"start-1\",{\"transactionId\":7,\"idTagInfo\":{\"status\":\"Accepted\"}}]",
    ) {
    Ok(frame) => frame
    Err(error) => fail(error.message())
  }
  match
    table.complete(
      response,
      @mooncharge.MessageDirection::CentralSystemToChargePoint,
      100,
    ) {
    Ok(@mooncharge.CorrelatedResponse::Result(id, action, payload)) => {
      let id_text = match id {
        @mooncharge.MessageId::Text(value) => value
        @mooncharge.MessageId::Number(value) => value
        @mooncharge.MessageId::Null => "null"
      }
      println("id=\{id_text} action=\{action} payload=\{payload.stringify()}")
    }
    Ok(_) => fail("expected CALLRESULT")
    Err(_) => fail("failed to correlate response")
  }
  println("pending=\{table.pending_count()}")
}
