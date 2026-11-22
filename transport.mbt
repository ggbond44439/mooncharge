///|
#derive(Eq, @debug.Debug)
pub(all) enum TransportState {
  Disconnected
  Connecting
  Connected
  Reconnecting
  Closed
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ReconnectPolicy {
  base_delay_ms : Int64
  max_delay_ms : Int64
  max_attempts : Int32
}

///|
pub fn ReconnectPolicy::new(
  base_delay_ms : Int64,
  max_delay_ms : Int64,
  max_attempts~ : Int32 = 0,
) -> Result[ReconnectPolicy, TransportError] {
  if base_delay_ms <= 0 || max_delay_ms < base_delay_ms || max_attempts < 0 {
    Err(InvalidReconnectPolicy)
  } else {
    Ok({ base_delay_ms, max_delay_ms, max_attempts, })
  }
}

///|
pub fn ReconnectPolicy::delay_for_attempt(
  self : ReconnectPolicy,
  attempt : Int32,
) -> Int64 {
  let mut delay = self.base_delay_ms
  let mut current = 1
  while current < attempt && delay < self.max_delay_ms {
    if delay > self.max_delay_ms / 2 {
      delay = self.max_delay_ms
    } else {
      delay = delay * 2
    }
    current = current + 1
  }
  if delay > self.max_delay_ms {
    self.max_delay_ms
  } else {
    delay
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum TransportEvent {
  Open
  Opened
  TextReceived(String)
  OpenFailed(String)
  PeerClosed(String)
  LocalClose(String)
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum TransportAction {
  StartConnect
  TransportReady(Int64)
  SendText(String)
  FrameReceived(VersionedFrame)
  ProtocolFailure(ProtocolError)
  CloseTransport(String)
  ScheduleReconnect(Int64, Int32)
  StopReconnect
  RejectedEvent(String, TransportState)
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum TransportError {
  InvalidReconnectPolicy
  InvalidMaxOutbound(Int32)
  UnsupportedVersion(OcppVersion)
  NotConnected(TransportState)
  QueueFull(Int32)
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct OcppTransport {
  version : OcppVersion
  mut state : TransportState
  max_outbound : Int32
  reconnect_policy : ReconnectPolicy
  mut reconnect_attempt : Int32
  mut generation : Int64
  mut outbound : Array[String]
  mut last_error : String?
}

///|
pub fn OcppTransport::new(
  version : OcppVersion,
  max_outbound : Int32,
  reconnect_policy : ReconnectPolicy,
) -> Result[OcppTransport, TransportError] {
  if !version.is_supported() {
    return Err(UnsupportedVersion(version))
  }
  if max_outbound <= 0 {
    return Err(InvalidMaxOutbound(max_outbound))
  }
  Ok({
    version,
    state: Disconnected,
    max_outbound,
    reconnect_policy,
    reconnect_attempt: 0,
    generation: 0,
    outbound: [],
    last_error: None,
  })
}

///|
fn reconnect_actions(
  transport : OcppTransport,
  reason : String,
) -> Array[TransportAction] {
  let attempt = transport.reconnect_attempt + 1
  if transport.reconnect_policy.max_attempts > 0 &&
    attempt > transport.reconnect_policy.max_attempts {
    transport.state = Closed
    transport.outbound = []
    transport.last_error = Some(reason)
    [CloseTransport(reason), StopReconnect]
  } else {
    transport.state = Reconnecting
    transport.reconnect_attempt = attempt
    transport.last_error = Some(reason)
    [
      ScheduleReconnect(
        transport.reconnect_policy.delay_for_attempt(attempt),
        attempt,
      ),
    ]
  }
}

///|
pub fn OcppTransport::handle(
  self : OcppTransport,
  event : TransportEvent,
) -> Array[TransportAction] {
  match event {
    Open =>
      match self.state {
        Disconnected | Reconnecting => {
          self.state = Connecting
          [StartConnect]
        }
        _ => [RejectedEvent("Open", self.state)]
      }
    Opened =>
      match self.state {
        Connecting => {
          self.state = Connected
          self.reconnect_attempt = 0
          self.generation = self.generation + 1
          self.last_error = None
          [TransportReady(self.generation)]
        }
        _ => [RejectedEvent("Opened", self.state)]
      }
    TextReceived(text) =>
      match self.state {
        Connected =>
          match parse_versioned_frame(self.version, text) {
            Ok(frame) => [FrameReceived(frame)]
            Err(error) => {
              self.last_error = Some(error.message())
              [ProtocolFailure(error)]
            }
          }
        _ => [RejectedEvent("TextReceived", self.state)]
      }
    OpenFailed(reason) =>
      match self.state {
        Connecting => reconnect_actions(self, reason)
        _ => [RejectedEvent("OpenFailed", self.state)]
      }
    PeerClosed(reason) =>
      match self.state {
        Connected => reconnect_actions(self, reason)
        _ => [RejectedEvent("PeerClosed", self.state)]
      }
    LocalClose(reason) =>
      if self.state == Closed {
        [RejectedEvent("LocalClose", self.state)]
      } else {
        self.state = Closed
        self.outbound = []
        self.last_error = Some(reason)
        [CloseTransport(reason), StopReconnect]
      }
  }
}

///|
pub fn OcppTransport::queue_frame(
  self : OcppTransport,
  frame : Frame,
) -> Result[Unit, TransportError] {
  if self.state != Connected {
    return Err(NotConnected(self.state))
  }
  if self.outbound.length() >= self.max_outbound {
    return Err(QueueFull(self.max_outbound))
  }
  self.outbound.push(frame.encode())
  Ok(())
}

///|
pub fn OcppTransport::flush(
  self : OcppTransport,
) -> Result[Array[TransportAction], TransportError] {
  if self.state != Connected {
    return Err(NotConnected(self.state))
  }
  let actions = self.outbound.map(fn(text) { SendText(text) })
  self.outbound = []
  Ok(actions)
}

///|
pub fn OcppTransport::state(self : OcppTransport) -> TransportState {
  self.state
}

///|
pub fn OcppTransport::generation(self : OcppTransport) -> Int64 {
  self.generation
}

///|
pub fn OcppTransport::reconnect_attempt(self : OcppTransport) -> Int32 {
  self.reconnect_attempt
}

///|
pub fn OcppTransport::pending_count(self : OcppTransport) -> Int32 {
  self.outbound.length()
}

///|
pub fn OcppTransport::last_error(self : OcppTransport) -> String? {
  self.last_error
}
