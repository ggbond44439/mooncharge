///|
fn main raise {
  let profile : @mooncharge.ChargingProfile = {
    charging_profile_id: 40,
    transaction_id: None,
    stack_level: 1,
    charging_profile_purpose: @mooncharge.ChargingProfilePurpose::TxDefaultProfile,
    charging_profile_kind: @mooncharge.ChargingProfileKind::Recurring,
    recurrency_kind: Some(@mooncharge.RecurrencyKind::Daily),
    valid_from: None,
    valid_to: None,
    charging_schedule: {
      start_schedule: None,
      duration: Some(3_600),
      min_charging_rate: None,
      charging_rate_unit: @mooncharge.ChargingRateUnit::Watts,
      periods: [
        { start_period: 0, limit: 22_000.0, number_phases: None, },
        { start_period: 1_800, limit: 11_000.0, number_phases: None, },
      ],
    },
  }
  let validity = @mooncharge.EpochInterval::new(0, None).unwrap()
  let timed : @mooncharge.TimedChargingProfile = {
    profile,
    validity: Some(validity),
    schedule_start_epoch: 1_000,
    transaction_start_epoch: None,
  }
  let decision = match
    @mooncharge.evaluate_timed_charging_profiles(
      [timed],
      None,
      1_000 + 86_400 + 2_000,
    ) {
    Ok(decision) => decision
    Err(_) => fail("no active timed profile")
  }
  println(
    "profile=\{decision.profile_id} limit=\{decision.limit} W capped=\{decision.capped_by_charge_point_max}",
  )
}
