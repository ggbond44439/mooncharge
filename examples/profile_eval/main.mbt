///|
fn profile(
  id : Int32,
  purpose : @mooncharge.ChargingProfilePurpose,
  stack_level : Int32,
  limit : Double,
) -> @mooncharge.ChargingProfile {
  {
    charging_profile_id: id,
    transaction_id: if purpose == @mooncharge.ChargingProfilePurpose::TxProfile {
      Some(42)
    } else {
      None
    },
    stack_level,
    charging_profile_purpose: purpose,
    charging_profile_kind: @mooncharge.ChargingProfileKind::Absolute,
    recurrency_kind: None,
    valid_from: None,
    valid_to: None,
    charging_schedule: {
      start_schedule: None,
      duration: Some(3600),
      min_charging_rate: None,
      charging_rate_unit: @mooncharge.ChargingRateUnit::Amps,
      periods: [{ start_period: 0, limit, number_phases: None, }],
    },
  }
}

///|
fn main raise {
  let profiles = [
    profile(
      1,
      @mooncharge.ChargingProfilePurpose::ChargePointMaxProfile,
      1,
      20.0,
    ),
    profile(2, @mooncharge.ChargingProfilePurpose::TxDefaultProfile, 1, 16.0),
    profile(3, @mooncharge.ChargingProfilePurpose::TxProfile, 2, 32.0),
  ]
  match @mooncharge.evaluate_charging_profiles(profiles, Some(42), 120) {
    Ok(decision) =>
      println(
        "profile=\{decision.profile_id} limit=\{decision.limit} A capped=\{decision.capped_by_charge_point_max}",
      )
    Err(_) => fail("no active profile")
  }
}
