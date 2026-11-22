///|
fn main raise {
  let policy = match @mooncharge.ReconnectPolicy::new(200, 5_000) {
    Ok(policy) => policy
    Err(_) => fail("failed to create reconnect policy")
  }
  let transport = match
    @mooncharge.OcppTransport::new(@mooncharge.OcppVersion::V16J, 8, policy) {
    Ok(transport) => transport
    Err(_) => fail("failed to create transport")
  }
  let start = transport.handle(@mooncharge.TransportEvent::Open)
  println(
    "start_connect=\{start[0] == @mooncharge.TransportAction::StartConnect}",
  )
  let ready = transport.handle(@mooncharge.TransportEvent::Opened)
  match ready[0] {
    @mooncharge.TransportAction::TransportReady(generation) =>
      println("ready_generation=\{generation}")
    _ => fail("expected transport ready")
  }
  let received = transport.handle(
    @mooncharge.TransportEvent::TextReceived("[2,\"hb-1\",\"Heartbeat\",{}]"),
  )
  match received[0] {
    @mooncharge.TransportAction::FrameReceived(value) =>
      match value.frame {
        @mooncharge.Call(_, action, _) => println("received_action=\{action}")
        _ => fail("expected a CALL frame")
      }
    _ => fail("expected a received frame")
  }
  let outbound = match
    @mooncharge.parse_frame("[2,\"hb-out\",\"Heartbeat\",{}]") {
    Ok(frame) => frame
    Err(_) => fail("failed to build outbound frame")
  }
  match transport.queue_frame(outbound) {
    Ok(_) => println("queued=\{transport.pending_count()}")
    Err(_) => fail("failed to queue outbound frame")
  }
  match transport.flush() {
    Ok(actions) => println("send_actions=\{actions.length()}")
    Err(_) => fail("failed to flush outbound frame")
  }
  let reconnect = transport.handle(
    @mooncharge.TransportEvent::PeerClosed("socket closed"),
  )
  match reconnect[0] {
    @mooncharge.TransportAction::ScheduleReconnect(delay, attempt) =>
      println("reconnect_delay_ms=\{delay} attempt=\{attempt}")
    _ => fail("expected reconnect schedule")
  }
  ignore(transport.handle(@mooncharge.TransportEvent::Open))
  let ready_again = transport.handle(@mooncharge.TransportEvent::Opened)
  match ready_again[0] {
    @mooncharge.TransportAction::TransportReady(generation) =>
      println("ready_generation=\{generation}")
    _ => fail("expected transport to reconnect")
  }
  let closed = transport.handle(
    @mooncharge.TransportEvent::LocalClose("application shutdown"),
  )
  println(
    "closed=\{transport.state() == @mooncharge.TransportState::Closed} actions=\{closed.length()}",
  )
}
