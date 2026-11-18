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
