# Changelog

## Unreleased

### Added

- Configurable `FrameLimits` for input bytes, nesting depth, message-id/action
  byte lengths and payload field count.
- Duplicate JSON key rejection by default, with an explicit compatibility mode.
- Explicit protocol-version context through `OcppVersion` and
  `VersionedFrame`, with version-bound parsing, dispatch, direction lookup and
  conformance audit APIs.
- Typed Heartbeat, MeterValues, StatusNotification, StopTransaction, diagnostics,
  firmware, CancelReservation, ClearCache and UnlockConnector payloads,
  including strict empty-confirmation codecs.
- Sans-I/O pending-call correlation with message-id matching, deadline expiry,
  response-direction checks, bounded capacity and CALLERROR preservation.
- Station-level multi-connector state with atomic status batches, station-wide
  availability, fault recovery, aggregate summaries and consistency diagnostics.
- Reservation lifecycle management and local authorization stores with Full and
  Differential updates, version checks, expiry and typed wire messages.
- Timed charging-profile evaluation with caller-mapped validity intervals,
  Absolute/Relative schedules, Daily/Weekly recurrence and stack replacement.
- Explicit DC and AC electrical models for validated ampere/watt conversion,
  phase-count checks and normalized charging decisions.
- Versioned JSON snapshots for station, transaction, reservation, local-auth and
  timed-profile state, with v1 migration, idempotent restore and consistency
  validation.
- Deterministic `OcppTransport` lifecycle with generation IDs, exponential
  reconnect backoff, retry limits, bounded outbound queues and protocol-error
  isolation.
- Typed `GetDiagnostics` and `UpdateFirmware` requests and confirmations,
  including retry scheduling, diagnostic file names and strict empty firmware
  acknowledgements.
- Typed TriggerMessage, ExtendedTriggerMessage and GetCompositeSchedule actions,
  including trigger targets, connector scope and full charging schedules.
- Typed log upload, security-event and signed-firmware workflows, including log
  filters, upload states, firmware verification states and signature material.
- Typed certificate installation, deletion, discovery, CSR signing and signed
  certificate-chain actions, completing all 39 OCPP 1.6 action payloads.
- Complete 39-action OCPP 1.6 conformance catalog with request direction,
  required fields and typed-coverage metadata.
- Payload and CALL audit APIs for unknown actions, wrong directions, invalid
  payload shape and missing required fields.
- `conformance summary`, `action` and `audit` CLI commands.
- Conformance audit example and executable baseline documentation.

### Fixed

- `BootNotificationResponse` now uses the standard `interval` field.
- Added missing OCPP 1.6 actions, including `ClearChargingProfile`,
  certificate, local-authorization, reservation and trigger messages.

## 0.1.0 - 2026-11-18

### Added

- OCPP 1.6J JSON-RPC framing for `CALL`, `CALLRESULT`, and `CALLERROR`.
- Direction-aware typed call dispatch with extension preservation.
- Boot, heartbeat, authorization, status, transaction, meter, data transfer,
  reset, availability, configuration, and smart-charging message codecs.
- Connector transaction state machine with meter regression protection.
- Charging profile validation, precedence, stack-level selection, schedule
  expiry, and charge-point maximum caps.
- CLI commands for frame inspection, action direction, typed dispatch, and
  charging-profile evaluation.
- Three runnable examples and cross-target CI.

### Scope

- OCPP 1.6J protocol semantics only.
- No transport, persistence, certificate provisioning, or billing logic.
- No silent conversion between ampere and watt charging-rate units.
