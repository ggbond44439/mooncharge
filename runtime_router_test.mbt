///|
fn router_frame(text : String) -> @mooncharge.Frame raise {
  match @mooncharge.parse_frame(text) {
    Ok(frame) => frame
    Err(_) => fail("failed to parse test frame")
  }
}

///|
fn router_object(text : String) -> Json raise {
  match router_frame(text) {
    @mooncharge.Call(_, _, payload) => payload
    @mooncharge.CallResult(_, payload) => payload
    _ => fail("expected an object payload")
  }
}

///|
fn heartbeat_handler(
  call : @mooncharge.TypedCall,
) -> Result[Json, @mooncharge.RpcError] {
  match call {
    @mooncharge.TypedCall::Heartbeat(_) =>
      Ok(Json::object({ "currentTime": Json::string("2026-11-22T12:00:00Z") }))
    _ =>
      Err({
        code: @mooncharge.RpcErrorCode::NotImplemented,
        description: "handler not implemented",
        details: Json::object(Map([])),
      })
  }
}

///|
test "request router dispatches typed calls and preserves message ids" {
  let router = @mooncharge.OcppRequestRouter::new(
    @mooncharge.OcppVersion::V16J,
    8,
  ).unwrap()
  let frame = router_frame("[2,\"hb-1\",\"Heartbeat\",{}]")
  let response = router
    .handle(
      frame,
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
      heartbeat_handler,
    )
    .unwrap()
  assert_eq(
    response,
    router_frame("[3,\"hb-1\",{\"currentTime\":\"2026-11-22T12:00:00Z\"}]"),
  )
  assert_eq(router.seen_count(), 1)
}

///|
test "request router converts handler failures into CALLERROR" {
  let router = @mooncharge.OcppRequestRouter::new(
    @mooncharge.OcppVersion::V16J,
    8,
  ).unwrap()
  let frame = router_frame(
    "[2,\"auth-1\",\"Authorize\",{\"idTag\":\"RFID-1\"}]",
  )
  let response = router
    .handle(
      frame,
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
      heartbeat_handler,
    )
    .unwrap()
  assert_eq(
    response,
    @mooncharge.CallError(@mooncharge.MessageId::Text("auth-1"), {
      code: @mooncharge.RpcErrorCode::NotImplemented,
      description: "handler not implemented",
      details: router_object("[3,\"ignored\",{}]"),
    }),
  )
}

///|
test "request router turns malformed payloads and directions into protocol errors" {
  let router = @mooncharge.OcppRequestRouter::new(
    @mooncharge.OcppVersion::V16J,
    8,
  ).unwrap()
  let malformed = router_frame("[2,\"hb-bad\",\"Heartbeat\",{\"extra\":1}]")
  let response = router
    .handle(
      malformed,
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
      heartbeat_handler,
    )
    .unwrap()
  assert_eq(
    response,
    @mooncharge.CallError(@mooncharge.MessageId::Text("hb-bad"), {
      code: @mooncharge.RpcErrorCode::PropertyConstraintViolation,
      description: "payload must be a JSON object",
      details: router_object("[3,\"ignored\",{}]"),
    }),
  )
  let wrong_direction = router_frame("[2,\"hb-wrong\",\"Heartbeat\",{}]")
  let response = router
    .handle(
      wrong_direction,
      @mooncharge.MessageDirection::CentralSystemToChargePoint,
      heartbeat_handler,
    )
    .unwrap()
  assert_eq(
    response,
    @mooncharge.CallError(@mooncharge.MessageId::Text("hb-wrong"), {
      code: @mooncharge.RpcErrorCode::FormationViolation,
      description: "request has the wrong OCPP direction",
      details: router_object("[3,\"ignored\",{}]"),
    }),
  )
}

///|
test "request router rejects duplicate ids and evicts only oldest entries" {
  let router = @mooncharge.OcppRequestRouter::new(
    @mooncharge.OcppVersion::V16J,
    2,
  ).unwrap()
  for id in ["1", "2"] {
    let frame = router_frame("[2,\"" + id + "\",\"Heartbeat\",{}]")
    ignore(
      router
      .handle(
        frame,
        @mooncharge.MessageDirection::ChargePointToCentralSystem,
        heartbeat_handler,
      )
      .unwrap(),
    )
  }
  assert_eq(router.seen_count(), 2)
  assert_eq(
    router.handle(
      router_frame("[2,\"2\",\"Heartbeat\",{}]"),
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
      heartbeat_handler,
    ),
    Err(
      @mooncharge.RouterError::DuplicateRequest(
        @mooncharge.MessageId::Text("2"),
      ),
    ),
  )
  ignore(
    router
    .handle(
      router_frame("[2,\"3\",\"Heartbeat\",{}]"),
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
      heartbeat_handler,
    )
    .unwrap(),
  )
  assert_eq(router.seen_count(), 2)
  ignore(
    router
    .handle(
      router_frame("[2,\"1\",\"Heartbeat\",{}]"),
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
      heartbeat_handler,
    )
    .unwrap(),
  )
  router.clear_seen()
  assert_eq(router.seen_count(), 0)
}

///|
test "request router validates constructor and handler output" {
  assert_eq(
    @mooncharge.OcppRequestRouter::new(@mooncharge.OcppVersion::V201, 1),
    Err(
      @mooncharge.RouterError::UnsupportedVersion(@mooncharge.OcppVersion::V201),
    ),
  )
  assert_eq(
    @mooncharge.OcppRequestRouter::new(@mooncharge.OcppVersion::V16J, 0),
    Err(@mooncharge.RouterError::InvalidMaxSeen(0)),
  )
  let router = @mooncharge.OcppRequestRouter::new(
    @mooncharge.OcppVersion::V16J,
    1,
  ).unwrap()
  assert_eq(
    router.handle(
      router_frame("[3,\"not-call\",{}]"),
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
      heartbeat_handler,
    ),
    Err(@mooncharge.RouterError::NotACall),
  )
  assert_eq(
    router.handle(
      router_frame("[2,\"invalid-payload\",\"Heartbeat\",{}]"),
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
      fn(_) { Ok(Json::array([])) },
    ),
    Err(@mooncharge.RouterError::InvalidHandlerPayload),
  )
}
