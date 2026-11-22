///|
fn reconnect_policy(
  base_delay_ms : Int64,
  max_delay_ms : Int64,
  max_attempts : Int32,
) -> @mooncharge.ReconnectPolicy raise {
  match
    @mooncharge.ReconnectPolicy::new(base_delay_ms, max_delay_ms, max_attempts~) {
    Ok(policy) => policy
    Err(_) => fail("invalid reconnect policy")
  }
}

///|
fn connected_transport(
  max_outbound~ : Int32 = 2,
) -> @mooncharge.OcppTransport raise {
  let transport = match
    @mooncharge.OcppTransport::new(
      @mooncharge.OcppVersion::V16J,
      max_outbound,
      reconnect_policy(100, 1_000, 3),
    ) {
    Ok(transport) => transport
    Err(_) => fail("failed to create transport")
  }
  assert_eq(transport.handle(@mooncharge.TransportEvent::Open), [
    @mooncharge.TransportAction::StartConnect,
  ])
  assert_eq(transport.handle(@mooncharge.TransportEvent::Opened), [
    @mooncharge.TransportAction::TransportReady(1),
  ])
  transport
}

///|
fn heartbeat_frame() -> @mooncharge.Frame raise {
  match @mooncharge.parse_frame("[2,\"hb-out\",\"Heartbeat\",{}]") {
    Ok(frame) => frame
    Err(_) => fail("failed to parse heartbeat frame")
  }
}

///|
test "reconnect policy validates bounds and caps exponential backoff" {
  assert_eq(
    @mooncharge.ReconnectPolicy::new(0, 1_000),
    Err(@mooncharge.TransportError::InvalidReconnectPolicy),
  )
  assert_eq(
    @mooncharge.ReconnectPolicy::new(2_000, 1_000),
    Err(@mooncharge.TransportError::InvalidReconnectPolicy),
  )
  assert_eq(
    @mooncharge.ReconnectPolicy::new(100, 1_000, max_attempts=-1),
    Err(@mooncharge.TransportError::InvalidReconnectPolicy),
  )
  let policy = reconnect_policy(100, 1_000, 0)
  assert_eq(policy.delay_for_attempt(1), 100)
  assert_eq(policy.delay_for_attempt(2), 200)
  assert_eq(policy.delay_for_attempt(3), 400)
  assert_eq(policy.delay_for_attempt(4), 800)
  assert_eq(policy.delay_for_attempt(5), 1_000)
  assert_eq(policy.delay_for_attempt(10_000), 1_000)
  let huge = reconnect_policy(
    4_611_686_018_427_387_904, 9_223_372_036_854_775_807, 0,
  )
  assert_eq(huge.delay_for_attempt(2), 9_223_372_036_854_775_807)
}

///|
test "transport validates version and bounded outbound queue" {
  let policy = reconnect_policy(100, 1_000, 0)
  assert_eq(
    @mooncharge.OcppTransport::new(@mooncharge.OcppVersion::V201, 1, policy),
    Err(
      @mooncharge.TransportError::UnsupportedVersion(
        @mooncharge.OcppVersion::V201,
      ),
    ),
  )
  assert_eq(
    @mooncharge.OcppTransport::new(@mooncharge.OcppVersion::V16J, 0, policy),
    Err(@mooncharge.TransportError::InvalidMaxOutbound(0)),
  )
}

///|
test "transport opens, receives typed frames, and rejects invalid events" {
  let transport = match
    @mooncharge.OcppTransport::new(
      @mooncharge.OcppVersion::V16J,
      1,
      reconnect_policy(100, 1_000, 0),
    ) {
    Ok(transport) => transport
    Err(_) => fail("failed to create transport")
  }
  assert_eq(transport.state(), @mooncharge.TransportState::Disconnected)
  assert_eq(transport.handle(@mooncharge.TransportEvent::Opened), [
    @mooncharge.TransportAction::RejectedEvent(
      "Opened",
      @mooncharge.TransportState::Disconnected,
    ),
  ])
  assert_eq(transport.handle(@mooncharge.TransportEvent::Open), [
    @mooncharge.TransportAction::StartConnect,
  ])
  assert_eq(transport.handle(@mooncharge.TransportEvent::Open), [
    @mooncharge.TransportAction::RejectedEvent(
      "Open",
      @mooncharge.TransportState::Connecting,
    ),
  ])
  assert_eq(transport.handle(@mooncharge.TransportEvent::Opened), [
    @mooncharge.TransportAction::TransportReady(1),
  ])
  assert_eq(transport.state(), @mooncharge.TransportState::Connected)
  let received = transport.handle(
    @mooncharge.TransportEvent::TextReceived("[2,\"hb-1\",\"Heartbeat\",{}]"),
  )
  assert_eq(received.length(), 1)
  match received[0] {
    @mooncharge.TransportAction::FrameReceived(value) => {
      assert_eq(value.version, @mooncharge.OcppVersion::V16J)
      match value.frame {
        @mooncharge.Call(id, action, _) => {
          assert_eq(id, @mooncharge.MessageId::Text("hb-1"))
          assert_eq(action, "Heartbeat")
        }
        _ => fail("expected CALL")
      }
    }
    _ => fail("expected FrameReceived")
  }
  assert_eq(
    transport.handle(@mooncharge.TransportEvent::LocalClose("maintenance")),
    [
      @mooncharge.TransportAction::CloseTransport("maintenance"),
      @mooncharge.TransportAction::StopReconnect,
    ],
  )
  assert_eq(transport.state(), @mooncharge.TransportState::Closed)
  assert_eq(transport.last_error(), Some("maintenance"))
}

///|
test "protocol failures keep the connection open and record diagnostics" {
  let transport = connected_transport()
  let actions = transport.handle(
    @mooncharge.TransportEvent::TextReceived("not-json"),
  )
  assert_eq(actions.length(), 1)
  match actions[0] {
    @mooncharge.TransportAction::ProtocolFailure(error) =>
      assert_eq(error, @mooncharge.ProtocolError::InvalidJson)
    _ => fail("expected ProtocolFailure")
  }
  assert_eq(transport.state(), @mooncharge.TransportState::Connected)
  assert_true(transport.last_error() is Some(_))
}

///|
test "open failures and peer closes schedule exponential reconnects" {
  let connecting = match
    @mooncharge.OcppTransport::new(
      @mooncharge.OcppVersion::V16J,
      1,
      reconnect_policy(250, 1_000, 3),
    ) {
    Ok(transport) => transport
    Err(_) => fail("failed to create transport")
  }
  ignore(connecting.handle(@mooncharge.TransportEvent::Open))
  assert_eq(
    connecting.handle(@mooncharge.TransportEvent::OpenFailed("refused")),
    [@mooncharge.TransportAction::ScheduleReconnect(250, 1)],
  )
  assert_eq(connecting.state(), @mooncharge.TransportState::Reconnecting)
  assert_eq(connecting.reconnect_attempt(), 1)
  assert_eq(connecting.last_error(), Some("refused"))
  ignore(connecting.handle(@mooncharge.TransportEvent::Open))
  assert_eq(
    connecting.handle(@mooncharge.TransportEvent::OpenFailed("timeout")),
    [@mooncharge.TransportAction::ScheduleReconnect(500, 2)],
  )
  ignore(connecting.handle(@mooncharge.TransportEvent::Open))
  assert_eq(connecting.handle(@mooncharge.TransportEvent::Opened), [
    @mooncharge.TransportAction::TransportReady(1),
  ])
  assert_eq(connecting.reconnect_attempt(), 0)
  assert_eq(
    connecting.handle(@mooncharge.TransportEvent::PeerClosed("network")),
    [@mooncharge.TransportAction::ScheduleReconnect(250, 1)],
  )
  assert_eq(connecting.state(), @mooncharge.TransportState::Reconnecting)
}

///|
test "successful reconnect increments generation and clears stale errors" {
  let transport = connected_transport()
  ignore(transport.handle(@mooncharge.TransportEvent::PeerClosed("network")))
  ignore(transport.handle(@mooncharge.TransportEvent::Open))
  assert_eq(transport.handle(@mooncharge.TransportEvent::Opened), [
    @mooncharge.TransportAction::TransportReady(2),
  ])
  assert_eq(transport.generation(), 2)
  assert_eq(transport.reconnect_attempt(), 0)
  assert_eq(transport.last_error(), None)
}

///|
test "outbound frames survive a transient reconnect" {
  let transport = connected_transport()
  let frame = heartbeat_frame()
  assert_eq(transport.queue_frame(frame), Ok(()))
  ignore(transport.handle(@mooncharge.TransportEvent::PeerClosed("network")))
  ignore(transport.handle(@mooncharge.TransportEvent::Open))
  assert_eq(transport.handle(@mooncharge.TransportEvent::Opened), [
    @mooncharge.TransportAction::TransportReady(2),
  ])
  assert_eq(transport.pending_count(), 1)
  assert_eq(
    transport.flush(),
    Ok([@mooncharge.TransportAction::SendText(frame.encode())]),
  )
}

///|
test "reconnect exhaustion closes transport and discards pending output" {
  let transport = match
    @mooncharge.OcppTransport::new(
      @mooncharge.OcppVersion::V16J,
      2,
      reconnect_policy(100, 400, 2),
    ) {
    Ok(transport) => transport
    Err(_) => fail("failed to create transport")
  }
  ignore(transport.handle(@mooncharge.TransportEvent::Open))
  ignore(transport.handle(@mooncharge.TransportEvent::Opened))
  assert_eq(transport.queue_frame(heartbeat_frame()), Ok(()))
  assert_eq(transport.pending_count(), 1)
  ignore(transport.handle(@mooncharge.TransportEvent::PeerClosed("first")))
  ignore(transport.handle(@mooncharge.TransportEvent::Open))
  assert_eq(
    transport.handle(@mooncharge.TransportEvent::OpenFailed("second")),
    [@mooncharge.TransportAction::ScheduleReconnect(200, 2)],
  )
  ignore(transport.handle(@mooncharge.TransportEvent::Open))
  assert_eq(
    transport.handle(@mooncharge.TransportEvent::OpenFailed("exhausted")),
    [
      @mooncharge.TransportAction::CloseTransport("exhausted"),
      @mooncharge.TransportAction::StopReconnect,
    ],
  )
  assert_eq(transport.state(), @mooncharge.TransportState::Closed)
  assert_eq(transport.pending_count(), 0)
  assert_eq(transport.last_error(), Some("exhausted"))
}

///|
test "outbound queue requires a live connection and enforces capacity" {
  let transport = connected_transport(max_outbound=2)
  let frame = heartbeat_frame()
  assert_eq(transport.queue_frame(frame), Ok(()))
  assert_eq(transport.queue_frame(frame), Ok(()))
  assert_eq(
    transport.queue_frame(frame),
    Err(@mooncharge.TransportError::QueueFull(2)),
  )
  let actions = match transport.flush() {
    Ok(actions) => actions
    Err(_) => fail("flush failed while connected")
  }
  assert_eq(actions, [
    @mooncharge.TransportAction::SendText(frame.encode()),
    @mooncharge.TransportAction::SendText(frame.encode()),
  ])
  assert_eq(transport.pending_count(), 0)
  ignore(transport.handle(@mooncharge.TransportEvent::PeerClosed("network")))
  assert_eq(
    transport.queue_frame(frame),
    Err(
      @mooncharge.TransportError::NotConnected(
        @mooncharge.TransportState::Reconnecting,
      ),
    ),
  )
  assert_eq(
    transport.flush(),
    Err(
      @mooncharge.TransportError::NotConnected(
        @mooncharge.TransportState::Reconnecting,
      ),
    ),
  )
}

///|
test "local close drains output and prevents reconnection" {
  let transport = connected_transport()
  assert_eq(transport.queue_frame(heartbeat_frame()), Ok(()))
  assert_eq(
    transport.handle(@mooncharge.TransportEvent::LocalClose("shutdown")),
    [
      @mooncharge.TransportAction::CloseTransport("shutdown"),
      @mooncharge.TransportAction::StopReconnect,
    ],
  )
  assert_eq(transport.pending_count(), 0)
  assert_eq(transport.handle(@mooncharge.TransportEvent::Open), [
    @mooncharge.TransportAction::RejectedEvent(
      "Open",
      @mooncharge.TransportState::Closed,
    ),
  ])
  assert_eq(transport.handle(@mooncharge.TransportEvent::LocalClose("again")), [
    @mooncharge.TransportAction::RejectedEvent(
      "LocalClose",
      @mooncharge.TransportState::Closed,
    ),
  ])
}
