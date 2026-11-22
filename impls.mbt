///|
pub extend MessageDirection with Eq::{not_equal, equal}

///|
pub extend MessageDirection with @debug.Debug::{to_repr}

///|
pub extend OcppAction with Eq::{not_equal, equal}

///|
pub extend OcppAction with @debug.Debug::{to_repr}

///|
pub extend ProtocolError with Eq::{not_equal, equal}

///|
pub extend ProtocolError with @debug.Debug::{to_repr}

///|
pub extend ProtocolError with Show::{to_string, output}

///|
pub extend MessageId with Eq::{not_equal, equal}

///|
pub extend MessageId with @debug.Debug::{to_repr}

///|
pub extend RpcErrorCode with Eq::{not_equal, equal}

///|
pub extend RpcErrorCode with @debug.Debug::{to_repr}

///|
pub extend RpcError with Eq::{not_equal, equal}

///|
pub extend RpcError with @debug.Debug::{to_repr}

///|
pub extend Frame with Eq::{not_equal, equal}

///|
pub extend Frame with @debug.Debug::{to_repr}

///|
pub extend RegistrationStatus with Eq::{not_equal, equal}

///|
pub extend RegistrationStatus with @debug.Debug::{to_repr}

///|
pub extend AuthorizationStatus with Eq::{not_equal, equal}

///|
pub extend AuthorizationStatus with @debug.Debug::{to_repr}

///|
pub extend ChargePointStatus with Eq::{not_equal, equal}

///|
pub extend ChargePointStatus with @debug.Debug::{to_repr}

///|
pub extend ChargePointErrorCode with Eq::{not_equal, equal}

///|
pub extend ChargePointErrorCode with @debug.Debug::{to_repr}

///|
pub extend StopReason with Eq::{not_equal, equal}

///|
pub extend StopReason with @debug.Debug::{to_repr}

///|
pub extend IdTagInfo with Eq::{not_equal, equal}

///|
pub extend IdTagInfo with @debug.Debug::{to_repr}

///|
pub extend BootNotificationRequest with Eq::{not_equal, equal}

///|
pub extend BootNotificationRequest with @debug.Debug::{to_repr}

///|
pub extend BootNotificationResponse with Eq::{not_equal, equal}

///|
pub extend BootNotificationResponse with @debug.Debug::{to_repr}

///|
pub extend HeartbeatResponse with Eq::{not_equal, equal}

///|
pub extend HeartbeatResponse with @debug.Debug::{to_repr}

///|
pub extend StatusNotificationRequest with Eq::{not_equal, equal}

///|
pub extend StatusNotificationRequest with @debug.Debug::{to_repr}

///|
pub extend AuthorizeRequest with Eq::{not_equal, equal}

///|
pub extend AuthorizeRequest with @debug.Debug::{to_repr}

///|
pub extend AuthorizeResponse with Eq::{not_equal, equal}

///|
pub extend AuthorizeResponse with @debug.Debug::{to_repr}

///|
pub extend StartTransactionRequest with Eq::{not_equal, equal}

///|
pub extend StartTransactionRequest with @debug.Debug::{to_repr}

///|
pub extend StartTransactionResponse with Eq::{not_equal, equal}

///|
pub extend StartTransactionResponse with @debug.Debug::{to_repr}

///|
pub extend StopTransactionRequest with Eq::{not_equal, equal}

///|
pub extend StopTransactionRequest with @debug.Debug::{to_repr}

///|
pub extend SampledValue with Eq::{not_equal, equal}

///|
pub extend SampledValue with @debug.Debug::{to_repr}

///|
pub extend MeterValue with Eq::{not_equal, equal}

///|
pub extend MeterValue with @debug.Debug::{to_repr}

///|
pub extend MeterValuesRequest with Eq::{not_equal, equal}

///|
pub extend MeterValuesRequest with @debug.Debug::{to_repr}

///|
pub extend ChargingProfilePurpose with Eq::{not_equal, equal}

///|
pub extend ChargingProfilePurpose with @debug.Debug::{to_repr}

///|
pub extend ChargingProfileKind with Eq::{not_equal, equal}

///|
pub extend ChargingProfileKind with @debug.Debug::{to_repr}

///|
pub extend ChargingRateUnit with Eq::{not_equal, equal}

///|
pub extend ChargingRateUnit with @debug.Debug::{to_repr}

///|
pub extend ChargingSchedulePeriod with Eq::{not_equal, equal}

///|
pub extend ChargingSchedulePeriod with @debug.Debug::{to_repr}

///|
pub extend ChargingSchedule with Eq::{not_equal, equal}

///|
pub extend ChargingSchedule with @debug.Debug::{to_repr}

///|
pub extend ChargingProfile with Eq::{not_equal, equal}

///|
pub extend ChargingProfile with @debug.Debug::{to_repr}

///|
pub extend ChargingProfileError with Eq::{not_equal, equal}

///|
pub extend ChargingProfileError with @debug.Debug::{to_repr}

///|
pub extend ChargingDecision with Eq::{not_equal, equal}

///|
pub extend ChargingDecision with @debug.Debug::{to_repr}

///|
pub extend ChargingTransaction with Eq::{not_equal, equal}

///|
pub extend ChargingTransaction with @debug.Debug::{to_repr}

///|
pub extend ConnectorSession with Eq::{not_equal, equal}

///|
pub extend ConnectorSession with @debug.Debug::{to_repr}

///|
pub extend SessionError with Eq::{not_equal, equal}

///|
pub extend SessionError with @debug.Debug::{to_repr}

///|
pub extend RemoteCommandStatus with Eq::{not_equal, equal}

///|
pub extend RemoteCommandStatus with @debug.Debug::{to_repr}

///|
pub extend RemoteStartTransactionRequest with Eq::{not_equal, equal}

///|
pub extend RemoteStartTransactionRequest with @debug.Debug::{to_repr}

///|
pub extend RemoteStartTransactionResponse with Eq::{not_equal, equal}

///|
pub extend RemoteStartTransactionResponse with @debug.Debug::{to_repr}

///|
pub extend RemoteStopTransactionRequest with Eq::{not_equal, equal}

///|
pub extend RemoteStopTransactionRequest with @debug.Debug::{to_repr}

///|
pub extend RemoteStopTransactionResponse with Eq::{not_equal, equal}

///|
pub extend RemoteStopTransactionResponse with @debug.Debug::{to_repr}

///|
pub extend ResetType with Eq::{not_equal, equal}

///|
pub extend ResetType with @debug.Debug::{to_repr}

///|
pub extend ResetRequest with Eq::{not_equal, equal}

///|
pub extend ResetRequest with @debug.Debug::{to_repr}

///|
pub extend ResetResponse with Eq::{not_equal, equal}

///|
pub extend ResetResponse with @debug.Debug::{to_repr}

///|
pub extend AvailabilityType with Eq::{not_equal, equal}

///|
pub extend AvailabilityType with @debug.Debug::{to_repr}

///|
pub extend ChangeAvailabilityRequest with Eq::{not_equal, equal}

///|
pub extend ChangeAvailabilityRequest with @debug.Debug::{to_repr}

///|
pub extend ChangeAvailabilityResponse with Eq::{not_equal, equal}

///|
pub extend ChangeAvailabilityResponse with @debug.Debug::{to_repr}

///|
pub extend ConfigurationStatus with Eq::{not_equal, equal}

///|
pub extend ConfigurationStatus with @debug.Debug::{to_repr}

///|
pub extend ChangeConfigurationRequest with Eq::{not_equal, equal}

///|
pub extend ChangeConfigurationRequest with @debug.Debug::{to_repr}

///|
pub extend ChangeConfigurationResponse with Eq::{not_equal, equal}

///|
pub extend ChangeConfigurationResponse with @debug.Debug::{to_repr}

///|
pub extend GetConfigurationRequest with Eq::{not_equal, equal}

///|
pub extend GetConfigurationRequest with @debug.Debug::{to_repr}

///|
pub extend ConfigurationKey with Eq::{not_equal, equal}

///|
pub extend ConfigurationKey with @debug.Debug::{to_repr}

///|
pub extend GetConfigurationResponse with Eq::{not_equal, equal}

///|
pub extend GetConfigurationResponse with @debug.Debug::{to_repr}

///|
pub extend ChargingProfileStatus with Eq::{not_equal, equal}

///|
pub extend ChargingProfileStatus with @debug.Debug::{to_repr}

///|
pub extend SetChargingProfileRequest with Eq::{not_equal, equal}

///|
pub extend SetChargingProfileRequest with @debug.Debug::{to_repr}

///|
pub extend SetChargingProfileResponse with Eq::{not_equal, equal}

///|
pub extend SetChargingProfileResponse with @debug.Debug::{to_repr}

///|
pub extend ClearChargingProfileRequest with Eq::{not_equal, equal}

///|
pub extend ClearChargingProfileRequest with @debug.Debug::{to_repr}

///|
pub extend ClearChargingProfileStatus with Eq::{not_equal, equal}

///|
pub extend ClearChargingProfileStatus with @debug.Debug::{to_repr}

///|
pub extend ClearChargingProfileResponse with Eq::{not_equal, equal}

///|
pub extend ClearChargingProfileResponse with @debug.Debug::{to_repr}

///|
pub extend TypedCall with Eq::{not_equal, equal}

///|
pub extend TypedCall with @debug.Debug::{to_repr}

///|
pub extend DispatchError with Eq::{not_equal, equal}

///|
pub extend DispatchError with @debug.Debug::{to_repr}

///|
pub extend DataTransferRequest with Eq::{not_equal, equal}

///|
pub extend DataTransferRequest with @debug.Debug::{to_repr}

///|
pub extend DataTransferStatus with Eq::{not_equal, equal}

///|
pub extend DataTransferStatus with @debug.Debug::{to_repr}

///|
pub extend DataTransferResponse with Eq::{not_equal, equal}

///|
pub extend DataTransferResponse with @debug.Debug::{to_repr}

///|
pub extend PayloadCoverage with Eq::{not_equal, equal}

///|
pub extend PayloadCoverage with @debug.Debug::{to_repr}

///|
pub extend PayloadPhase with Eq::{not_equal, equal}

///|
pub extend PayloadPhase with @debug.Debug::{to_repr}

///|
pub extend ActionSpec with Eq::{not_equal, equal}

///|
pub extend ActionSpec with @debug.Debug::{to_repr}

///|
pub extend ConformanceSummary with Eq::{not_equal, equal}

///|
pub extend ConformanceSummary with @debug.Debug::{to_repr}

///|
pub extend ConformanceIssue with Eq::{not_equal, equal}

///|
pub extend ConformanceIssue with @debug.Debug::{to_repr}

///|
pub extend ConformanceReport with Eq::{not_equal, equal}

///|
pub extend ConformanceReport with @debug.Debug::{to_repr}

///|
pub extend OcppVersion with Eq::{not_equal, equal}

///|
pub extend OcppVersion with @debug.Debug::{to_repr}

///|
pub extend VersionedFrame with Eq::{not_equal, equal}

///|
pub extend VersionedFrame with @debug.Debug::{to_repr}

///|
pub extend HeartbeatRequest with Eq::{not_equal, equal}

///|
pub extend HeartbeatRequest with @debug.Debug::{to_repr}

///|
pub extend MeterValuesResponse with Eq::{not_equal, equal}

///|
pub extend MeterValuesResponse with @debug.Debug::{to_repr}

///|
pub extend StatusNotificationResponse with Eq::{not_equal, equal}

///|
pub extend StatusNotificationResponse with @debug.Debug::{to_repr}

///|
pub extend StopTransactionResponse with Eq::{not_equal, equal}

///|
pub extend StopTransactionResponse with @debug.Debug::{to_repr}

///|
pub extend DiagnosticsStatus with Eq::{not_equal, equal}

///|
pub extend DiagnosticsStatus with @debug.Debug::{to_repr}

///|
pub extend DiagnosticsStatusNotificationRequest with Eq::{not_equal, equal}

///|
pub extend DiagnosticsStatusNotificationRequest with @debug.Debug::{to_repr}

///|
pub extend DiagnosticsStatusNotificationResponse with Eq::{not_equal, equal}

///|
pub extend DiagnosticsStatusNotificationResponse with @debug.Debug::{to_repr}

///|
pub extend FirmwareStatus with Eq::{not_equal, equal}

///|
pub extend FirmwareStatus with @debug.Debug::{to_repr}

///|
pub extend FirmwareStatusNotificationRequest with Eq::{not_equal, equal}

///|
pub extend FirmwareStatusNotificationRequest with @debug.Debug::{to_repr}

///|
pub extend FirmwareStatusNotificationResponse with Eq::{not_equal, equal}

///|
pub extend FirmwareStatusNotificationResponse with @debug.Debug::{to_repr}

///|
pub extend CancelReservationStatus with Eq::{not_equal, equal}

///|
pub extend CancelReservationStatus with @debug.Debug::{to_repr}

///|
pub extend CancelReservationRequest with Eq::{not_equal, equal}

///|
pub extend CancelReservationRequest with @debug.Debug::{to_repr}

///|
pub extend CancelReservationResponse with Eq::{not_equal, equal}

///|
pub extend CancelReservationResponse with @debug.Debug::{to_repr}

///|
pub extend ClearCacheRequest with Eq::{not_equal, equal}

///|
pub extend ClearCacheRequest with @debug.Debug::{to_repr}

///|
pub extend ClearCacheStatus with Eq::{not_equal, equal}

///|
pub extend ClearCacheStatus with @debug.Debug::{to_repr}

///|
pub extend ClearCacheResponse with Eq::{not_equal, equal}

///|
pub extend ClearCacheResponse with @debug.Debug::{to_repr}

///|
pub extend UnlockConnectorRequest with Eq::{not_equal, equal}

///|
pub extend UnlockConnectorRequest with @debug.Debug::{to_repr}

///|
pub extend UnlockStatus with Eq::{not_equal, equal}

///|
pub extend UnlockStatus with @debug.Debug::{to_repr}

///|
pub extend UnlockConnectorResponse with Eq::{not_equal, equal}

///|
pub extend UnlockConnectorResponse with @debug.Debug::{to_repr}

///|
pub extend PendingCall with Eq::{not_equal, equal}

///|
pub extend PendingCall with @debug.Debug::{to_repr}

///|
pub extend CorrelatedResponse with Eq::{not_equal, equal}

///|
pub extend CorrelatedResponse with @debug.Debug::{to_repr}

///|
pub extend CorrelationError with Eq::{not_equal, equal}

///|
pub extend CorrelationError with @debug.Debug::{to_repr}

///|
pub extend PendingCallTable with Eq::{not_equal, equal}

///|
pub extend PendingCallTable with @debug.Debug::{to_repr}

///|
pub extend StationMode with Eq::{not_equal, equal}

///|
pub extend StationMode with @debug.Debug::{to_repr}

///|
pub extend ConnectorStatusUpdate with Eq::{not_equal, equal}

///|
pub extend ConnectorStatusUpdate with @debug.Debug::{to_repr}

///|
pub extend StationError with Eq::{not_equal, equal}

///|
pub extend StationError with @debug.Debug::{to_repr}

///|
pub extend StationConsistencyIssue with Eq::{not_equal, equal}

///|
pub extend StationConsistencyIssue with @debug.Debug::{to_repr}

///|
pub extend StationSummary with Eq::{not_equal, equal}

///|
pub extend StationSummary with @debug.Debug::{to_repr}

///|
pub extend ChargePointSession with Eq::{not_equal, equal}

///|
pub extend ChargePointSession with @debug.Debug::{to_repr}

///|
pub extend ReservationStatus with Eq::{not_equal, equal}

///|
pub extend ReservationStatus with @debug.Debug::{to_repr}

///|
pub extend ReserveNowRequest with Eq::{not_equal, equal}

///|
pub extend ReserveNowRequest with @debug.Debug::{to_repr}

///|
pub extend ReserveNowResponse with Eq::{not_equal, equal}

///|
pub extend ReserveNowResponse with @debug.Debug::{to_repr}

///|
pub extend Reservation with Eq::{not_equal, equal}

///|
pub extend Reservation with @debug.Debug::{to_repr}

///|
pub extend ReservationError with Eq::{not_equal, equal}

///|
pub extend ReservationError with @debug.Debug::{to_repr}

///|
pub extend ReservationBook with Eq::{not_equal, equal}

///|
pub extend ReservationBook with @debug.Debug::{to_repr}

///|
pub extend LocalListUpdateType with Eq::{not_equal, equal}

///|
pub extend LocalListUpdateType with @debug.Debug::{to_repr}

///|
pub extend LocalAuthorizationEntry with Eq::{not_equal, equal}

///|
pub extend LocalAuthorizationEntry with @debug.Debug::{to_repr}

///|
pub extend SendLocalListRequest with Eq::{not_equal, equal}

///|
pub extend SendLocalListRequest with @debug.Debug::{to_repr}

///|
pub extend LocalListUpdateStatus with Eq::{not_equal, equal}

///|
pub extend LocalListUpdateStatus with @debug.Debug::{to_repr}

///|
pub extend SendLocalListResponse with Eq::{not_equal, equal}

///|
pub extend SendLocalListResponse with @debug.Debug::{to_repr}

///|
pub extend GetLocalListVersionRequest with Eq::{not_equal, equal}

///|
pub extend GetLocalListVersionRequest with @debug.Debug::{to_repr}

///|
pub extend GetLocalListVersionResponse with Eq::{not_equal, equal}

///|
pub extend GetLocalListVersionResponse with @debug.Debug::{to_repr}

///|
pub extend LocalAuthorizationError with Eq::{not_equal, equal}

///|
pub extend LocalAuthorizationError with @debug.Debug::{to_repr}

///|
pub extend LocalAuthorizationStore with Eq::{not_equal, equal}

///|
pub extend LocalAuthorizationStore with @debug.Debug::{to_repr}

///|
pub extend RecurrencyKind with Eq::{not_equal, equal}

///|
pub extend RecurrencyKind with @debug.Debug::{to_repr}

///|
pub extend EpochInterval with Eq::{not_equal, equal}

///|
pub extend EpochInterval with @debug.Debug::{to_repr}

///|
pub extend TimedChargingProfile with Eq::{not_equal, equal}

///|
pub extend TimedChargingProfile with @debug.Debug::{to_repr}

///|
pub extend ChargingLimit with Eq::{not_equal, equal}

///|
pub extend ChargingLimit with @debug.Debug::{to_repr}

///|
pub extend ElectricalSystem with Eq::{not_equal, equal}

///|
pub extend ElectricalSystem with @debug.Debug::{to_repr}

///|
pub extend PowerConversionError with Eq::{not_equal, equal}

///|
pub extend PowerConversionError with @debug.Debug::{to_repr}

///|
pub extend ElectricalModel with Eq::{not_equal, equal}

///|
pub extend ElectricalModel with @debug.Debug::{to_repr}

///|
pub extend SnapshotError with Eq::{not_equal, equal}

///|
pub extend SnapshotError with @debug.Debug::{to_repr}

///|
pub extend ChargePointSnapshot with Eq::{not_equal, equal}

///|
pub extend ChargePointSnapshot with @debug.Debug::{to_repr}

///|
pub extend TransportState with Eq::{not_equal, equal}

///|
pub extend TransportState with @debug.Debug::{to_repr}

///|
pub extend ReconnectPolicy with Eq::{not_equal, equal}

///|
pub extend ReconnectPolicy with @debug.Debug::{to_repr}

///|
pub extend TransportEvent with Eq::{not_equal, equal}

///|
pub extend TransportEvent with @debug.Debug::{to_repr}

///|
pub extend TransportAction with Eq::{not_equal, equal}

///|
pub extend TransportAction with @debug.Debug::{to_repr}

///|
pub extend TransportError with Eq::{not_equal, equal}

///|
pub extend TransportError with @debug.Debug::{to_repr}

///|
pub extend OcppTransport with Eq::{not_equal, equal}

///|
pub extend OcppTransport with @debug.Debug::{to_repr}
