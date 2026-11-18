# OCPP 1.6J coverage

MoonCharge separates wire framing from action payloads. Every well-formed CALL
can be decoded even when its action has no typed payload yet.

## Framing

| Frame | Validation |
| --- | --- |
| `CALL` | Four-element array, valid id, non-empty action, object payload |
| `CALLRESULT` | Three-element array, valid id, object payload |
| `CALLERROR` | Five-element array, valid id, non-empty code/description, object details |

Unknown OCPP error-code strings are preserved as `RpcErrorCode::Unknown`.
Unknown actions are preserved as `TypedCall::UnsupportedAction`.

## Typed calls

| Action | Request | Confirmation |
| --- | --- | --- |
| `Authorize` | Typed | Typed |
| `BootNotification` | Typed | Typed |
| `DataTransfer` | Typed | Typed |
| `Heartbeat` | Empty object | Typed |
| `MeterValues` | Typed | Empty object |
| `StartTransaction` | Typed | Typed |
| `StatusNotification` | Typed | Empty object |
| `StopTransaction` | Typed | Empty object |
| `RemoteStartTransaction` | Typed | Typed |
| `RemoteStopTransaction` | Typed | Typed |
| `Reset` | Typed | Typed |
| `ChangeAvailability` | Typed | Typed |
| `ChangeConfiguration` | Typed | Typed |
| `GetConfiguration` | Typed | Typed |
| `SetChargingProfile` | Typed | Typed |
| `ClearChargingProfile` | Typed | Typed |
| `CancelReservation` | Registry only | Registry only |
| `ClearCache` | Registry only | Registry only |
| `DiagnosticsStatusNotification` | Registry only | Registry only |
| `FirmwareStatusNotification` | Registry only | Registry only |
| `UnlockConnector` | Registry only | Registry only |

“Registry only” means MoonCharge validates the action name and direction but
does not yet expose a typed payload for it. The original JSON remains available
in `Frame::Call`.

## Trading invariants

`ConnectorSession` enforces:

- one active transaction per connector;
- non-empty id tag;
- non-negative transaction id and meter start;
- matching active transaction id on stop/release;
- `meterStop >= meterStart`;
- `Finishing` before explicit release to `Available`.

The session value contains no global state, timers, or hidden I/O.

## Charging profiles

The evaluator checks:

- non-empty period lists;
- strictly increasing `startPeriod` values;
- non-negative periods and limits;
- `duration > last startPeriod`;
- transaction ids only on transaction profiles;
- transaction-profile precedence over default profiles;
- highest stack level within the selected purpose;
- charge-point maximum cap;
- matching rate units.

Schedule selection uses caller-supplied elapsed seconds. Calendar parsing,
time-zone conversion, recurring window expansion, and hardware voltage/phase
conversion remain application concerns.

## Deliberately out of scope

- WebSocket and HTTP transport
- OCPP Security Profiles and certificate installation
- OCPP 2.0.1 complete transaction and device-model semantics
- Plug & Charge trust chains
- persistence, metering hardware, billing, and settlement
