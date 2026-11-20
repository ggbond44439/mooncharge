///|
/// Protocol versions recognized by the public API.
#derive(Eq, @debug.Debug)
pub(all) enum OcppVersion {
  V16J
  V201
}

///|
pub fn OcppVersion::label(self : OcppVersion) -> String {
  match self {
    V16J => "1.6J"
    V201 => "2.0.1"
  }
}

///|
pub fn OcppVersion::is_supported(self : OcppVersion) -> Bool {
  match self {
    V16J => true
    V201 => false
  }
}

///|
/// A decoded frame paired with the protocol version used to interpret it.
#derive(Eq, @debug.Debug)
pub(all) struct VersionedFrame {
  version : OcppVersion
  frame : Frame
}

///|
pub fn VersionedFrame::encode(self : VersionedFrame) -> String {
  self.frame.encode()
}

///|
pub fn parse_versioned_frame(
  version : OcppVersion,
  text : String,
) -> Result[VersionedFrame, ProtocolError] {
  parse_versioned_frame_with_limits(version, text, FrameLimits::default())
}

///|
pub fn parse_versioned_frame_with_limits(
  version : OcppVersion,
  text : String,
  limits : FrameLimits,
) -> Result[VersionedFrame, ProtocolError] {
  match version {
    V16J => {
      let frame = match parse_frame_with_limits(text, limits) {
        Ok(frame) => frame
        Err(error) => return Err(error)
      }
      Ok({ version, frame, })
    }
    V201 => Err(UnsupportedProtocolVersion(version))
  }
}

///|
pub fn versioned_action_direction(
  version : OcppVersion,
  action : String,
  is_request : Bool,
) -> Result[MessageDirection, ProtocolError] {
  match version {
    V16J => action_direction(action, is_request)
    V201 => Err(UnsupportedProtocolVersion(version))
  }
}

///|
pub fn dispatch_versioned_call(
  value : VersionedFrame,
  received_at : MessageDirection,
) -> Result[TypedCall, DispatchError] {
  match value.version {
    V16J => dispatch_call(value.frame, received_at)
    V201 => Err(UnsupportedVersion(value.version))
  }
}

///|
pub fn audit_versioned_frame(
  value : VersionedFrame,
  received_at : MessageDirection,
) -> ConformanceReport {
  match value.version {
    V16J => audit_frame(value.frame, received_at)
    V201 =>
      {
        action: "",
        phase: Request,
        issues: [UnsupportedVersion(value.version)],
      }
  }
}
