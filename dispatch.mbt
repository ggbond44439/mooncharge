///|
#derive(Eq, @debug.Debug)
pub(all) enum TypedCall {
  Authorize(AuthorizeRequest)
  BootNotification(BootNotificationRequest)
  DataTransfer(DataTransferRequest)
  StatusNotification(StatusNotificationRequest)
  StartTransaction(StartTransactionRequest)
  StopTransaction(StopTransactionRequest)
  MeterValues(MeterValuesRequest)
  RemoteStartTransaction(RemoteStartTransactionRequest)
  RemoteStopTransaction(RemoteStopTransactionRequest)
  Reset(ResetRequest)
  ChangeAvailability(ChangeAvailabilityRequest)
  ChangeConfiguration(ChangeConfigurationRequest)
  GetConfiguration(GetConfigurationRequest)
  SetChargingProfile(SetChargingProfileRequest)
  ClearChargingProfile(ClearChargingProfileRequest)
  UnsupportedAction(String, Json)
}

///|
pub fn TypedCall::action_name(self : TypedCall) -> String {
  match self {
    Authorize(_) => "Authorize"
    BootNotification(_) => "BootNotification"
    DataTransfer(_) => "DataTransfer"
    StatusNotification(_) => "StatusNotification"
    StartTransaction(_) => "StartTransaction"
    StopTransaction(_) => "StopTransaction"
    MeterValues(_) => "MeterValues"
    RemoteStartTransaction(_) => "RemoteStartTransaction"
    RemoteStopTransaction(_) => "RemoteStopTransaction"
    Reset(_) => "Reset"
    ChangeAvailability(_) => "ChangeAvailability"
    ChangeConfiguration(_) => "ChangeConfiguration"
    GetConfiguration(_) => "GetConfiguration"
    SetChargingProfile(_) => "SetChargingProfile"
    ClearChargingProfile(_) => "ClearChargingProfile"
    UnsupportedAction(action, _) => action
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum DispatchError {
  NotACall
  InvalidAction(ProtocolError)
  WrongDirection(MessageDirection, MessageDirection)
  InvalidPayload(ProtocolError)
}

///|
fn parse_typed_call(
  action : String,
  payload : Json,
) -> TypedCall raise ProtocolFailure {
  match action {
    "Authorize" => Authorize(parse_authorize_request(payload))
    "BootNotification" =>
      BootNotification(parse_boot_notification_request(payload))
    "DataTransfer" => DataTransfer(parse_data_transfer(payload))
    "StatusNotification" =>
      StatusNotification(parse_status_notification_request(payload))
    "StartTransaction" =>
      StartTransaction(parse_start_transaction_request(payload))
    "StopTransaction" =>
      StopTransaction(parse_stop_transaction_request(payload))
    "MeterValues" => MeterValues(parse_meter_values_request(payload))
    "RemoteStartTransaction" =>
      RemoteStartTransaction(parse_remote_start(payload))
    "RemoteStopTransaction" => RemoteStopTransaction(parse_remote_stop(payload))
    "Reset" => Reset(parse_reset_request(payload))
    "ChangeAvailability" =>
      ChangeAvailability(parse_change_availability(payload))
    "ChangeConfiguration" =>
      ChangeConfiguration(parse_change_configuration(payload))
    "GetConfiguration" => GetConfiguration(parse_get_configuration(payload))
    "SetChargingProfile" =>
      SetChargingProfile(parse_set_charging_profile(payload))
    "ClearChargingProfile" =>
      ClearChargingProfile(parse_clear_charging_profile(payload))
    other => UnsupportedAction(other, payload)
  }
}

///|
/// Decodes a CALL into a typed request after checking that it arrived from the
/// direction defined by OCPP 1.6J. Unknown but well-formed actions are returned
/// as `UnsupportedAction` so gateways can implement extensions without silently
/// dropping the payload.
pub fn dispatch_call(
  frame : Frame,
  received_at : MessageDirection,
) -> Result[TypedCall, DispatchError] {
  match frame {
    Call(_, action, payload) => {
      let expected = match action_direction(action, true) {
        Ok(direction) => direction
        Err(_) => return Ok(UnsupportedAction(action, payload))
      }
      if expected != received_at {
        return Err(WrongDirection(expected, received_at))
      }
      let call = parse_typed_call(action, payload) catch {
        Failure(error) => return Err(InvalidPayload(error))
      }
      Ok(call)
    }
    _ => Err(NotACall)
  }
}
