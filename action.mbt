///|
/// Direction of an OCPP 1.6J action.
#derive(Eq, @debug.Debug)
pub(all) enum MessageDirection {
  ChargePointToCentralSystem
  CentralSystemToChargePoint
}

///|
/// Supported OCPP 1.6J action names. Requests and confirmations share an action
/// name but travel in opposite directions.
#derive(Eq, @debug.Debug)
pub(all) enum OcppAction {
  Authorize
  BootNotification
  DataTransfer
  DiagnosticsStatusNotification
  FirmwareStatusNotification
  Heartbeat
  MeterValues
  StartTransaction
  StatusNotification
  StopTransaction
  CancelReservation
  ChangeAvailability
  ChangeConfiguration
  ClearCache
  GetConfiguration
  RemoteStartTransaction
  RemoteStopTransaction
  Reset
  SetChargingProfile
  UnlockConnector
}

///|
pub fn OcppAction::parse(value : String) -> OcppAction? {
  match value {
    "Authorize" => Some(Authorize)
    "BootNotification" => Some(BootNotification)
    "DataTransfer" => Some(DataTransfer)
    "DiagnosticsStatusNotification" => Some(DiagnosticsStatusNotification)
    "FirmwareStatusNotification" => Some(FirmwareStatusNotification)
    "Heartbeat" => Some(Heartbeat)
    "MeterValues" => Some(MeterValues)
    "StartTransaction" => Some(StartTransaction)
    "StatusNotification" => Some(StatusNotification)
    "StopTransaction" => Some(StopTransaction)
    "CancelReservation" => Some(CancelReservation)
    "ChangeAvailability" => Some(ChangeAvailability)
    "ChangeConfiguration" => Some(ChangeConfiguration)
    "ClearCache" => Some(ClearCache)
    "GetConfiguration" => Some(GetConfiguration)
    "RemoteStartTransaction" => Some(RemoteStartTransaction)
    "RemoteStopTransaction" => Some(RemoteStopTransaction)
    "Reset" => Some(Reset)
    "SetChargingProfile" => Some(SetChargingProfile)
    "UnlockConnector" => Some(UnlockConnector)
    _ => None
  }
}

///|
pub fn OcppAction::name(self : OcppAction) -> String {
  match self {
    Authorize => "Authorize"
    BootNotification => "BootNotification"
    DataTransfer => "DataTransfer"
    DiagnosticsStatusNotification => "DiagnosticsStatusNotification"
    FirmwareStatusNotification => "FirmwareStatusNotification"
    Heartbeat => "Heartbeat"
    MeterValues => "MeterValues"
    StartTransaction => "StartTransaction"
    StatusNotification => "StatusNotification"
    StopTransaction => "StopTransaction"
    CancelReservation => "CancelReservation"
    ChangeAvailability => "ChangeAvailability"
    ChangeConfiguration => "ChangeConfiguration"
    ClearCache => "ClearCache"
    GetConfiguration => "GetConfiguration"
    RemoteStartTransaction => "RemoteStartTransaction"
    RemoteStopTransaction => "RemoteStopTransaction"
    Reset => "Reset"
    SetChargingProfile => "SetChargingProfile"
    UnlockConnector => "UnlockConnector"
  }
}

///|
pub fn OcppAction::request_direction(self : OcppAction) -> MessageDirection {
  match self {
    CancelReservation
    | ChangeAvailability
    | ChangeConfiguration
    | ClearCache
    | GetConfiguration
    | RemoteStartTransaction
    | RemoteStopTransaction
    | Reset
    | SetChargingProfile
    | UnlockConnector => CentralSystemToChargePoint
    _ => ChargePointToCentralSystem
  }
}

///|
pub fn action_direction(
  action : String,
  is_request : Bool,
) -> Result[MessageDirection, ProtocolError] {
  let parsed = match OcppAction::parse(action) {
    Some(action) => action
    None => return Err(InvalidAction)
  }
  let request = parsed.request_direction()
  if is_request {
    Ok(request)
  } else {
    match request {
      ChargePointToCentralSystem => Ok(CentralSystemToChargePoint)
      CentralSystemToChargePoint => Ok(ChargePointToCentralSystem)
    }
  }
}
