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

- 26 typed requests;
- 26 typed confirmations;
- 13 catalog-only requests;
- 13 catalog-only confirmations.

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
| `GetDiagnostics` | Typed | Typed |
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
| `UpdateFirmware` | Typed | Typed |

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

`TimedChargingProfile` adds caller-mapped epoch evaluation. Profiles can carry
an exclusive-end `EpochInterval`, Relative schedules anchored to a transaction
start, and Daily or Weekly recurrence. Equal-purpose equal-stack profiles use
the later entry, matching OCPP replacement semantics.

## Electrical conversion

`ElectricalModel` makes ampere/watt conversion explicit. It supports DC,
single-phase AC, three-phase line-to-line AC and three-phase line-to-neutral AC.
Voltage, power factor and schedule phase count are validated before conversion;
the evaluator never silently converts between A and W.

## Persistence snapshots

`ChargePointSnapshot` defines schema version 2 with station mode, connectors,
transactions, reservations, local authorization lists and timed charging
profiles. `save_snapshot` and `load_snapshot` validate consistency and duplicate
identities. Version 1 connector-only documents are migrated automatically, and
unknown JSON fields are ignored for forward-compatible reads.

## Transport lifecycle

`OcppTransport` is a deterministic, sans-I/O connection state machine. It turns
application events into explicit actions:

| Event | Accepted state | Action |
| --- | --- | --- |
| `Open` | Disconnected, Reconnecting | `StartConnect` |
| `Opened` | Connecting | `TransportReady(generation)` |
| `TextReceived` | Connected | `FrameReceived` or `ProtocolFailure` |
| `OpenFailed` | Connecting | `ScheduleReconnect` or close |
| `PeerClosed` | Connected | `ScheduleReconnect` or close |
| `LocalClose` | Any open state | `CloseTransport`, `StopReconnect` |

Reconnect delay uses bounded exponential backoff (`base_delay_ms`, doubling,
`max_delay_ms`). A positive `max_attempts` closes the transport after exhaustion;
zero means unlimited retries. The caller owns sockets, TLS, timers and delivery.
The transport owns generation IDs, reconnect accounting and a bounded outbound
queue. Malformed text reports `ProtocolFailure` without implicitly dropping a
healthy connection, and local or exhausted closure clears pending output.

## Deliberately out of scope

- concrete WebSocket/socket, timer and HTTP implementations
- complete certificate provisioning and trust-chain management
- OCPP 2.0.1 complete transaction and device-model semantics
- Plug & Charge trust chains
- persistence, metering hardware, billing, and settlement
