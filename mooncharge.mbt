///|
/// MoonCharge provides a transport-neutral OCPP 1.6J protocol core.
///
/// Start with `parse_frame`, then decode the payload type for the action.
/// `ConnectorSession` owns transaction invariants, while
/// `evaluate_charging_profiles` resolves charging limits without reading a
/// clock or performing I/O.
