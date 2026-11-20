///|
#derive(Eq, @debug.Debug)
pub(all) enum PayloadCoverage {
  Typed
  CatalogOnly
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum PayloadPhase {
  Request
  Confirmation
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ActionSpec {
  action : String
  request_direction : MessageDirection
  request_coverage : PayloadCoverage
  response_coverage : PayloadCoverage
  request_required : Array[String]
  response_required : Array[String]
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ConformanceSummary {
  total_actions : Int32
  typed_requests : Int32
  typed_responses : Int32
  catalog_only_requests : Int32
  catalog_only_responses : Int32
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum ConformanceIssue {
  NotACall
  UnknownAction(String)
  WrongDirection(MessageDirection, MessageDirection)
  PayloadNotObject(PayloadPhase)
  MissingRequiredField(PayloadPhase, String)
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ConformanceReport {
  action : String
  phase : PayloadPhase
  issues : Array[ConformanceIssue]
}

///|
pub fn ConformanceReport::passed(self : ConformanceReport) -> Bool {
  self.issues.is_empty()
}

///|
fn spec(
  action : OcppAction,
  request_typed : Bool,
  response_typed : Bool,
  request_required : Array[String],
  response_required : Array[String],
) -> ActionSpec {
  {
    action: action.name(),
    request_direction: action.request_direction(),
    request_coverage: if request_typed {
      Typed
    } else {
      CatalogOnly
    },
    response_coverage: if response_typed {
      Typed
    } else {
      CatalogOnly
    },
    request_required,
    response_required,
  }
}

///|
/// Complete OCPP 1.6 action inventory used by the conformance baseline.
pub fn action_specs() -> Array[ActionSpec] {
  [
    spec(Authorize, true, true, ["idTag"], ["idTagInfo"]),
    spec(
      BootNotification,
      true,
      true,
      ["chargePointVendor", "chargePointModel"],
      ["status", "currentTime", "interval"],
    ),
    spec(CancelReservation, false, false, ["reservationId"], ["status"]),
    spec(CertificateSigned, false, false, ["certificateChain"], ["status"]),
    spec(ChangeAvailability, true, true, ["connectorId", "type"], ["status"]),
    spec(ChangeConfiguration, true, true, ["key", "value"], ["status"]),
    spec(ClearCache, false, false, [], ["status"]),
    spec(ClearChargingProfile, true, true, [], ["status"]),
    spec(DataTransfer, true, true, ["vendorId"], ["status"]),
    spec(DeleteCertificate, false, false, ["certificateHashData"], ["status"]),
    spec(DiagnosticsStatusNotification, false, false, ["status"], []),
    spec(ExtendedTriggerMessage, false, false, ["requestedMessage"], ["status"]),
    spec(FirmwareStatusNotification, false, false, ["status"], []),
    spec(GetCompositeSchedule, false, false, ["connectorId", "duration"], [
      "status",
    ]),
    spec(GetConfiguration, true, true, [], []),
    spec(GetDiagnostics, false, false, ["location"], []),
    spec(GetInstalledCertificateIds, false, false, ["certificateType"], [
      "status",
    ]),
    spec(GetLocalListVersion, false, false, [], ["listVersion"]),
    spec(GetLog, false, false, ["logType", "requestId", "log"], ["status"]),
    spec(Heartbeat, false, true, [], ["currentTime"]),
    spec(InstallCertificate, false, false, ["certificateType", "certificate"], [
      "status",
    ]),
    spec(LogStatusNotification, false, false, ["status"], []),
    spec(MeterValues, true, false, ["connectorId", "meterValue"], []),
    spec(RemoteStartTransaction, true, true, ["idTag"], ["status"]),
    spec(RemoteStopTransaction, true, true, ["transactionId"], ["status"]),
    spec(
      ReserveNow,
      false,
      false,
      ["connectorId", "expiryDate", "idTag", "reservationId"],
      ["status"],
    ),
    spec(Reset, true, true, ["type"], ["status"]),
    spec(SecurityEventNotification, false, false, ["type", "timestamp"], []),
    spec(SendLocalList, false, false, ["listVersion", "updateType"], ["status"]),
    spec(
      SetChargingProfile,
      true,
      true,
      ["connectorId", "csChargingProfiles"],
      ["status"],
    ),
    spec(SignCertificate, false, false, ["csr"], ["status"]),
    spec(SignedFirmwareStatusNotification, false, false, ["status"], []),
    spec(SignedUpdateFirmware, false, false, ["requestId", "firmware"], [
      "status",
    ]),
    spec(
      StartTransaction,
      true,
      true,
      ["connectorId", "idTag", "meterStart", "timestamp"],
      ["idTagInfo", "transactionId"],
    ),
    spec(
      StatusNotification,
      true,
      false,
      ["connectorId", "errorCode", "status"],
      [],
    ),
    spec(
      StopTransaction,
      true,
      false,
      ["transactionId", "timestamp", "meterStop"],
      [],
    ),
    spec(TriggerMessage, false, false, ["requestedMessage"], ["status"]),
    spec(UnlockConnector, false, false, ["connectorId"], ["status"]),
    spec(UpdateFirmware, false, false, ["location", "retrieveDate"], []),
  ]
}

///|
pub fn find_action_spec(action : String) -> ActionSpec? {
  for spec in action_specs() {
    if spec.action == action {
      return Some(spec)
    }
  }
  None
}

///|
pub fn conformance_summary() -> ConformanceSummary {
  let specs = action_specs()
  let mut typed_requests = 0
  let mut typed_responses = 0
  for spec in specs {
    if spec.request_coverage == Typed {
      typed_requests = typed_requests + 1
    }
    if spec.response_coverage == Typed {
      typed_responses = typed_responses + 1
    }
  }
  {
    total_actions: specs.length(),
    typed_requests,
    typed_responses,
    catalog_only_requests: specs.length() - typed_requests,
    catalog_only_responses: specs.length() - typed_responses,
  }
}

///|
fn reverse(direction : MessageDirection) -> MessageDirection {
  match direction {
    ChargePointToCentralSystem => CentralSystemToChargePoint
    CentralSystemToChargePoint => ChargePointToCentralSystem
  }
}

///|
fn expected_direction(
  spec : ActionSpec,
  phase : PayloadPhase,
) -> MessageDirection {
  match phase {
    Request => spec.request_direction
    Confirmation => reverse(spec.request_direction)
  }
}

///|
fn required_fields(spec : ActionSpec, phase : PayloadPhase) -> Array[String] {
  match phase {
    Request => spec.request_required
    Confirmation => spec.response_required
  }
}

///|
/// Audits one payload against the catalog without decoding its business type.
pub fn audit_payload(
  action : String,
  phase : PayloadPhase,
  received_at : MessageDirection,
  payload : Json,
) -> ConformanceReport {
  let issues : Array[ConformanceIssue] = []
  let spec = match find_action_spec(action) {
    Some(spec) => spec
    None => {
      issues.push(UnknownAction(action))
      return { action, phase, issues, }
    }
  }
  let expected = expected_direction(spec, phase)
  if expected != received_at {
    issues.push(WrongDirection(expected, received_at))
  }
  match payload {
    Json::Object(fields) =>
      for field in required_fields(spec, phase) {
        if fields.get(field) is None {
          issues.push(MissingRequiredField(phase, field))
        }
      }
    _ => issues.push(PayloadNotObject(phase))
  }
  { action, phase, issues, }
}

///|
/// Audits a CALL frame. Confirmation payloads require the caller to provide
/// their action because OCPP only echoes the message id in a CALLRESULT.
pub fn audit_frame(
  frame : Frame,
  received_at : MessageDirection,
) -> ConformanceReport {
  match frame {
    Call(_, action, payload) =>
      audit_payload(action, Request, received_at, payload)
    _ => { action: "", phase: Request, issues: [NotACall], }
  }
}
