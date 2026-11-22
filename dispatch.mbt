///|
#derive(Eq, @debug.Debug)
pub(all) enum TypedCall {
  Authorize(AuthorizeRequest)
  BootNotification(BootNotificationRequest)
  CancelReservation(CancelReservationRequest)
  ClearCache(ClearCacheRequest)
  DataTransfer(DataTransferRequest)
  DiagnosticsStatusNotification(DiagnosticsStatusNotificationRequest)
  ExtendedTriggerMessage(ExtendedTriggerMessageRequest)
  FirmwareStatusNotification(FirmwareStatusNotificationRequest)
  GetCompositeSchedule(GetCompositeScheduleRequest)
  GetDiagnostics(GetDiagnosticsRequest)
  GetLog(GetLogRequest)
  GetLocalListVersion(GetLocalListVersionRequest)
  Heartbeat(HeartbeatRequest)
  LogStatusNotification(LogStatusNotificationRequest)
  StatusNotification(StatusNotificationRequest)
  StartTransaction(StartTransactionRequest)
  StopTransaction(StopTransactionRequest)
  TriggerMessage(TriggerMessageRequest)
  MeterValues(MeterValuesRequest)
  RemoteStartTransaction(RemoteStartTransactionRequest)
  RemoteStopTransaction(RemoteStopTransactionRequest)
  ReserveNow(ReserveNowRequest)
  Reset(ResetRequest)
  SecurityEventNotification(SecurityEventNotificationRequest)
  SignedFirmwareStatusNotification(SignedFirmwareStatusNotificationRequest)
  SignedUpdateFirmware(SignedUpdateFirmwareRequest)
  ChangeAvailability(ChangeAvailabilityRequest)
  ChangeConfiguration(ChangeConfigurationRequest)
  GetConfiguration(GetConfigurationRequest)
  SetChargingProfile(SetChargingProfileRequest)
  ClearChargingProfile(ClearChargingProfileRequest)
  SendLocalList(SendLocalListRequest)
  UnlockConnector(UnlockConnectorRequest)
  UpdateFirmware(UpdateFirmwareRequest)
  UnsupportedAction(String, Json)
}

///|
pub fn TypedCall::action_name(self : TypedCall) -> String {
  match self {
    Authorize(_) => "Authorize"
    BootNotification(_) => "BootNotification"
    CancelReservation(_) => "CancelReservation"
    ClearCache(_) => "ClearCache"
    DataTransfer(_) => "DataTransfer"
    DiagnosticsStatusNotification(_) => "DiagnosticsStatusNotification"
    ExtendedTriggerMessage(_) => "ExtendedTriggerMessage"
    FirmwareStatusNotification(_) => "FirmwareStatusNotification"
    GetCompositeSchedule(_) => "GetCompositeSchedule"
    GetDiagnostics(_) => "GetDiagnostics"
    GetLog(_) => "GetLog"
    GetLocalListVersion(_) => "GetLocalListVersion"
    Heartbeat(_) => "Heartbeat"
    LogStatusNotification(_) => "LogStatusNotification"
    StatusNotification(_) => "StatusNotification"
    StartTransaction(_) => "StartTransaction"
    StopTransaction(_) => "StopTransaction"
    TriggerMessage(_) => "TriggerMessage"
    MeterValues(_) => "MeterValues"
    RemoteStartTransaction(_) => "RemoteStartTransaction"
    RemoteStopTransaction(_) => "RemoteStopTransaction"
    ReserveNow(_) => "ReserveNow"
    Reset(_) => "Reset"
    SecurityEventNotification(_) => "SecurityEventNotification"
    SignedFirmwareStatusNotification(_) => "SignedFirmwareStatusNotification"
    SignedUpdateFirmware(_) => "SignedUpdateFirmware"
    ChangeAvailability(_) => "ChangeAvailability"
    ChangeConfiguration(_) => "ChangeConfiguration"
    GetConfiguration(_) => "GetConfiguration"
    SetChargingProfile(_) => "SetChargingProfile"
    ClearChargingProfile(_) => "ClearChargingProfile"
    SendLocalList(_) => "SendLocalList"
    UnlockConnector(_) => "UnlockConnector"
    UpdateFirmware(_) => "UpdateFirmware"
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
  UnsupportedVersion(OcppVersion)
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
    "CancelReservation" => CancelReservation(parse_cancel_reservation(payload))
    "ClearCache" => ClearCache(parse_clear_cache_request(payload))
    "DataTransfer" => DataTransfer(parse_data_transfer(payload))
    "DiagnosticsStatusNotification" =>
      DiagnosticsStatusNotification(
        parse_diagnostics_status_notification(payload),
      )
    "ExtendedTriggerMessage" =>
      ExtendedTriggerMessage(parse_extended_trigger_message_request(payload))
    "FirmwareStatusNotification" =>
      FirmwareStatusNotification(parse_firmware_status_notification(payload))
    "GetCompositeSchedule" =>
      GetCompositeSchedule(parse_get_composite_schedule_request(payload))
    "GetDiagnostics" => GetDiagnostics(parse_get_diagnostics_request(payload))
    "GetLog" => GetLog(parse_get_log_request(payload))
    "GetLocalListVersion" =>
      GetLocalListVersion(parse_get_local_list_version(payload))
    "Heartbeat" => Heartbeat(parse_heartbeat_request(payload))
    "LogStatusNotification" =>
      LogStatusNotification(parse_log_status_notification_request(payload))
    "StatusNotification" =>
      StatusNotification(parse_status_notification_request(payload))
    "StartTransaction" =>
      StartTransaction(parse_start_transaction_request(payload))
    "StopTransaction" =>
      StopTransaction(parse_stop_transaction_request(payload))
    "TriggerMessage" => TriggerMessage(parse_trigger_message_request(payload))
    "MeterValues" => MeterValues(parse_meter_values_request(payload))
    "RemoteStartTransaction" =>
      RemoteStartTransaction(parse_remote_start(payload))
    "RemoteStopTransaction" => RemoteStopTransaction(parse_remote_stop(payload))
    "ReserveNow" => ReserveNow(parse_reserve_now(payload))
    "Reset" => Reset(parse_reset_request(payload))
    "SecurityEventNotification" =>
      SecurityEventNotification(parse_security_event_notification(payload))
    "SignedFirmwareStatusNotification" =>
      SignedFirmwareStatusNotification(
        parse_signed_firmware_status_notification(payload),
      )
    "SignedUpdateFirmware" =>
      SignedUpdateFirmware(parse_signed_update_firmware_request(payload))
    "ChangeAvailability" =>
      ChangeAvailability(parse_change_availability(payload))
    "ChangeConfiguration" =>
      ChangeConfiguration(parse_change_configuration(payload))
    "GetConfiguration" => GetConfiguration(parse_get_configuration(payload))
    "SetChargingProfile" =>
      SetChargingProfile(parse_set_charging_profile(payload))
    "ClearChargingProfile" =>
      ClearChargingProfile(parse_clear_charging_profile(payload))
    "SendLocalList" => SendLocalList(parse_send_local_list(payload))
    "UnlockConnector" => UnlockConnector(parse_unlock_connector(payload))
    "UpdateFirmware" => UpdateFirmware(parse_update_firmware_request(payload))
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
