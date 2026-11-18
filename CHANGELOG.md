# Changelog

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
