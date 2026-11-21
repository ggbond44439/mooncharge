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

`OcppVersion::V16J` is the supported protocol context. `VersionedFrame`,
`parse_versioned_frame`, `dispatch_versioned_call`,
`versioned_action_direction` and `audit_versioned_frame` require an explicit
version. `V201` is reserved and currently fails closed with
`UnsupportedProtocolVersion` or `UnsupportedVersion`.

`parse_frame` applies `FrameLimits::default()`. Callers handling untrusted
traffic can use `parse_frame_with_limits` to bound UTF-8 input bytes, nesting,
message-id length, action length and top-level payload field count. Duplicate
JSON keys are rejected by default to prevent ambiguous authorization or payload
interpretation.

## Executable baseline

The catalog contains 39 OCPP 1.6 actions and records their request direction,
required request fields, required confirmation fields and current payload
coverage. The initial baseline has:

- 24 typed requests;
- 24 typed confirmations;
- 15 catalog-only requests;
- 15 catalog-only confirmations.

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
| `CancelReservation` | Typed | Typed |
| `CertificateSigned` | Catalog only | Catalog only |
| `ChangeAvailability` | Typed | Typed |
| `ChangeConfiguration` | Typed | Typed |
| `ClearCache` | Typed | Typed |
| `ClearChargingProfile` | Typed | Typed |
| `DataTransfer` | Typed | Typed |
| `DeleteCertificate` | Catalog only | Catalog only |
| `DiagnosticsStatusNotification` | Typed | Typed |
| `ExtendedTriggerMessage` | Catalog only | Catalog only |
| `FirmwareStatusNotification` | Typed | Typed |
| `GetCompositeSchedule` | Catalog only | Catalog only |
| `GetConfiguration` | Typed | Typed |
| `GetDiagnostics` | Catalog only | Catalog only |
| `GetInstalledCertificateIds` | Catalog only | Catalog only |
| `GetLocalListVersion` | Typed | Typed |
| `GetLog` | Catalog only | Catalog only |
| `Heartbeat` | Typed | Typed |
| `InstallCertificate` | Catalog only | Catalog only |
| `LogStatusNotification` | Catalog only | Catalog only |
| `MeterValues` | Typed | Typed |
| `RemoteStartTransaction` | Typed | Typed |
| `RemoteStopTransaction` | Typed | Typed |
| `ReserveNow` | Typed | Typed |
| `Reset` | Typed | Typed |
| `SecurityEventNotification` | Catalog only | Catalog only |
| `SendLocalList` | Typed | Typed |
| `SetChargingProfile` | Typed | Typed |
| `SignCertificate` | Catalog only | Catalog only |
| `SignedFirmwareStatusNotification` | Catalog only | Catalog only |
| `SignedUpdateFirmware` | Catalog only | Catalog only |
| `StartTransaction` | Typed | Typed |
| `StatusNotification` | Typed | Typed |
| `StopTransaction` | Typed | Typed |
| `TriggerMessage` | Catalog only | Catalog only |
| `UnlockConnector` | Typed | Typed |
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

## Station state

`ChargePointSession` aggregates multiple `ConnectorSession` values. It supports
connector add/remove, connector 0 station-wide availability, atomic batch status
updates, fault recovery that preserves active transaction phase, aggregate
counts and consistency diagnostics for invalid, duplicate, charging-without-
transaction or inoperative-with-active-transaction snapshots.

## Request correlation

`PendingCallTable` stores outstanding CALL metadata by message id and explicit
protocol version. `insert` rejects null ids, duplicate ids, wrong request
directions, unknown actions and capacity overflow. `complete` accepts only
CALLRESULT/CALLERROR, validates the response direction, removes successful
entries, preserves CALLERROR as a correlated response and enforces caller-owned
deadlines. `expire` separates timeout cleanup from wall-clock access.

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
