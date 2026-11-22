///|
fn frame(text : String) -> @mooncharge.Frame raise {
  match @mooncharge.parse_frame(text) {
    Ok(frame) => frame
    Err(_) => fail("failed to parse frame")
  }
}

///|
fn handler(call : @mooncharge.TypedCall) -> Result[Json, @mooncharge.RpcError] {
  match call {
    @mooncharge.TypedCall::Heartbeat(_) =>
      Ok(Json::object({ "currentTime": Json::string("2026-11-22T12:00:00Z") }))
    @mooncharge.TypedCall::Authorize(request) =>
      Ok(
        Json::object({
          "idTagInfo": Json::object({
            "status": Json::string(
              if request.id_tag == "RFID-OK" {
                "Accepted"
              } else {
                "Invalid"
              },
            ),
          }),
        }),
      )
    _ =>
      Err({
        code: @mooncharge.RpcErrorCode::NotImplemented,
        description: "handler not implemented",
        details: Json::object(Map([])),
      })
  }
}

///|
fn main raise {
  let router = match
    @mooncharge.OcppRequestRouter::new(@mooncharge.OcppVersion::V16J, 8) {
    Ok(router) => router
    Err(_) => fail("failed to create router")
  }
  let heartbeat = frame("[2,\"hb-1\",\"Heartbeat\",{}]")
  let response = match
    router.handle(
      heartbeat,
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
      handler,
    ) {
    Ok(response) => response
    Err(_) => fail("failed to route heartbeat")
  }
  match response {
    @mooncharge.CallResult(id, _) => {
      let text = match id {
        @mooncharge.MessageId::Text(value) => value
        @mooncharge.MessageId::Number(value) => value
        @mooncharge.MessageId::Null => "null"
      }
      println("heartbeat_result=\{text}")
    }
    _ => fail("expected CALLRESULT")
  }
  let duplicate = router.handle(
    heartbeat,
    @mooncharge.MessageDirection::ChargePointToCentralSystem,
    handler,
  )
  println("duplicate_rejected=\{duplicate is Err(_)}")
  let authorize = frame("[2,\"auth-1\",\"Authorize\",{\"idTag\":\"RFID-OK\"}]")
  let accepted = match
    router.handle(
      authorize,
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
      handler,
    ) {
    Ok(@mooncharge.CallResult(_, payload)) => payload.stringify()
    _ => fail("expected authorize result")
  }
  println("authorize_payload=\{accepted} tracked=\{router.seen_count()}")
}
