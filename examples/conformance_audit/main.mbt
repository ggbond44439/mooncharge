///|
fn main raise {
  let summary = @mooncharge.conformance_summary()
  println(
    "actions=\{summary.total_actions} typed_requests=\{summary.typed_requests} typed_responses=\{summary.typed_responses}",
  )
  let valid = match
    @mooncharge.parse_frame(
      "[2,\"start-1\",\"StartTransaction\",{\"connectorId\":1,\"idTag\":\"RFID-1\",\"meterStart\":0,\"timestamp\":\"2026-11-20T00:00:00Z\"}]",
    ) {
    Ok(frame) => frame
    Err(error) => fail(error.message())
  }
  let valid_report = @mooncharge.audit_frame(
    valid,
    @mooncharge.MessageDirection::ChargePointToCentralSystem,
  )
  println(
    "valid=\{valid_report.passed()} issues=\{valid_report.issues.length()}",
  )
  let invalid = match
    @mooncharge.parse_frame(
      "[2,\"start-2\",\"StartTransaction\",{\"connectorId\":1,\"idTag\":\"RFID-1\"}]",
    ) {
    Ok(frame) => frame
    Err(error) => fail(error.message())
  }
  let invalid_report = @mooncharge.audit_frame(
    invalid,
    @mooncharge.MessageDirection::ChargePointToCentralSystem,
  )
  println(
    "valid=\{invalid_report.passed()} issues=\{invalid_report.issues.length()}",
  )
}
