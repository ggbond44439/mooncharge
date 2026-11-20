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
