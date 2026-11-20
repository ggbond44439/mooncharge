# OCPP 1.6J conformance coverage

MoonCharge separates wire framing from action payloads. Every well-formed CALL
can be inspected even when its action has no typed payload yet.

## Framing

| Frame | Validation |
| --- | --- |
| `CALL` | Four-element array, valid id, non-empty action, object payload |
| `CALLRESULT` | Three-element array, valid id, object payload |
| `CALLERROR` | Five-element array, valid id, non-empty code/description, object details |

Unknown OCPP error-code strings are preserved as `RpcErrorCode::Unknown`.
Unknown actions are preserved as `TypedCall::UnsupportedAction`.

## Executable baseline

The catalog contains 39 OCPP 1.6 actions and records their request direction,
required request fields, required confirmation fields and current payload
coverage. The initial baseline has:

- 15 typed requests;
- 13 typed confirmations;
- 24 catalog-only requests;
- 26 catalog-only confirmations.

The required-field inventory was checked against the public
`mobilityhouse/ocpp` OCPP 1.6 JSON Schemas. The catalog is available through:

- `action_specs()` for the complete inventory;
- `find_action_spec(action)` for one action;
- `conformance_summary()` for coverage counts;
- `audit_payload(...)` for request or confirmation validation;
- `audit_frame(...)` for complete CALL validation.

## Action matrix

| Action | Request | Confirmation |
| --- | --- | --- |
| `Authorize` | Typed | Typed |
| `BootNotification` | Typed | Typed |
| `CancelReservation` | Catalog only | Catalog only |
| `CertificateSigned` | Catalog only | Catalog only |
| `ChangeAvailability` | Typed | Typed |
| `ChangeConfiguration` | Typed | Typed |
| `ClearCache` | Catalog only | Catalog only |
| `ClearChargingProfile` | Typed | Typed |
| `DataTransfer` | Typed | Typed |
| `DeleteCertificate` | Catalog only | Catalog only |
| `DiagnosticsStatusNotification` | Catalog only | Catalog only |
| `ExtendedTriggerMessage` | Catalog only | Catalog only |
| `FirmwareStatusNotification` | Catalog only | Catalog only |
| `GetCompositeSchedule` | Catalog only | Catalog only |
| `GetConfiguration` | Typed | Typed |
| `GetDiagnostics` | Catalog only | Catalog only |
| `GetInstalledCertificateIds` | Catalog only | Catalog only |
| `GetLocalListVersion` | Catalog only | Catalog only |
| `GetLog` | Catalog only | Catalog only |
| `Heartbeat` | Catalog only | Typed |
| `InstallCertificate` | Catalog only | Catalog only |
| `LogStatusNotification` | Catalog only | Catalog only |
| `MeterValues` | Typed | Catalog only |
| `RemoteStartTransaction` | Typed | Typed |
| `RemoteStopTransaction` | Typed | Typed |
| `ReserveNow` | Catalog only | Catalog only |
| `Reset` | Typed | Typed |
| `SecurityEventNotification` | Catalog only | Catalog only |
| `SendLocalList` | Catalog only | Catalog only |
| `SetChargingProfile` | Typed | Typed |
| `SignCertificate` | Catalog only | Catalog only |
| `SignedFirmwareStatusNotification` | Catalog only | Catalog only |
| `SignedUpdateFirmware` | Catalog only | Catalog only |
| `StartTransaction` | Typed | Typed |
| `StatusNotification` | Typed | Catalog only |
| `StopTransaction` | Typed | Catalog only |
| `TriggerMessage` | Catalog only | Catalog only |
| `UnlockConnector` | Catalog only | Catalog only |
| `UpdateFirmware` | Catalog only | Catalog only |

“Catalog only” means MoonCharge exposes schema metadata and validates required
fields, but does not yet provide a dedicated typed payload for that direction.
The action name and direction are still checked, and the original JSON remains
available in `Frame::Call`.

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
- complete certificate provisioning and trust-chain management
- OCPP 2.0.1 complete transaction and device-model semantics
- Plug & Charge trust chains
- persistence, metering hardware, billing, and settlement
