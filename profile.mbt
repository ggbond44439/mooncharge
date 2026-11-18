///|
#derive(Eq, @debug.Debug)
pub(all) enum ChargingProfilePurpose {
  ChargePointMaxProfile
  TxDefaultProfile
  TxProfile
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum ChargingProfileKind {
  Absolute
  Recurring
  Relative
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum ChargingRateUnit {
  Amps
  Watts
}

///|
fn parse_profile_purpose(
  value : String,
) -> ChargingProfilePurpose raise ProtocolFailure {
  match value {
    "ChargePointMaxProfile" => ChargePointMaxProfile
    "TxDefaultProfile" => TxDefaultProfile
    "TxProfile" => TxProfile
    _ => refuse(UnsupportedValue("chargingProfilePurpose", value))
  }
}

///|
fn parse_profile_kind(
  value : String,
) -> ChargingProfileKind raise ProtocolFailure {
  match value {
    "Absolute" => Absolute
    "Recurring" => Recurring
    "Relative" => Relative
    _ => refuse(UnsupportedValue("chargingProfileKind", value))
  }
}

///|
fn parse_rate_unit(value : String) -> ChargingRateUnit raise ProtocolFailure {
  match value {
    "A" => Amps
    "W" => Watts
    _ => refuse(UnsupportedValue("chargingRateUnit", value))
  }
}

///|
fn rate_unit_name(value : ChargingRateUnit) -> String {
  match value {
    Amps => "A"
    Watts => "W"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ChargingSchedulePeriod {
  start_period : Int32
  limit : Double
  number_phases : Int32?
}

///|
fn parse_schedule_period(
  value : Json,
) -> ChargingSchedulePeriod raise ProtocolFailure {
  let start_period = required_nonnegative_int(value, "startPeriod")
  let limit = match object_field(value, "limit") {
    Json::Number(limit, ..) if limit >= 0.0 => limit
    _ => refuse(InvalidField("limit"))
  }
  {
    start_period,
    limit,
    number_phases: optional_nonnegative_int(value, "numberPhases"),
  }
}

///|
pub fn ChargingSchedulePeriod::from_json(
  value : Json,
) -> Result[ChargingSchedulePeriod, ProtocolError] {
  result_of(() => parse_schedule_period(value))
}

///|
pub fn ChargingSchedulePeriod::to_json(self : ChargingSchedulePeriod) -> Json {
  let fields : Map[String, Json] = {
    "startPeriod": int_json(self.start_period),
    "limit": Json::number(self.limit),
  }
  match self.number_phases {
    Some(value) => fields.set("numberPhases", int_json(value))
    None => ()
  }
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ChargingSchedule {
  start_schedule : String?
  duration : Int32?
  min_charging_rate : Double?
  charging_rate_unit : ChargingRateUnit
  periods : Array[ChargingSchedulePeriod]
}

///|
fn parse_charging_schedule(
  value : Json,
) -> ChargingSchedule raise ProtocolFailure {
  let unit = parse_rate_unit(required_string(value, "chargingRateUnit"))
  let period_items = required_array(value, "chargingSchedulePeriod")
  if period_items.is_empty() {
    refuse(InvalidField("chargingSchedulePeriod"))
  }
  let periods = []
  for item in period_items {
    periods.push(parse_schedule_period(item))
  }
  let duration = optional_nonnegative_int(value, "duration")
  let schedule_fields = match value {
    Json::Object(fields) => fields
    _ => refuse(InvalidPayload)
  }
  let min_charging_rate = match schedule_fields.get("minChargingRate") {
    Some(Json::Number(value, ..)) if value >= 0.0 => Some(value)
    Some(Json::Null) | None => None
    _ => refuse(InvalidField("minChargingRate"))
  }
  let schedule = {
    start_schedule: optional_string(value, "startSchedule"),
    duration,
    min_charging_rate,
    charging_rate_unit: unit,
    periods,
  }
  validate_schedule(schedule)
  schedule
}

///|
fn validate_schedule(schedule : ChargingSchedule) -> Unit raise ProtocolFailure {
  let mut previous = -1
  for period in schedule.periods {
    if period.start_period <= previous {
      refuse(InvalidField("chargingSchedulePeriod"))
    }
    previous = period.start_period
  }
  match schedule.duration {
    Some(duration) =>
      if duration <= previous {
        refuse(InvalidField("duration"))
      }
    None => ()
  }
}

///|
pub fn ChargingSchedule::from_json(
  value : Json,
) -> Result[ChargingSchedule, ProtocolError] {
  result_of(() => parse_charging_schedule(value))
}

///|
pub fn ChargingSchedule::to_json(self : ChargingSchedule) -> Json {
  let fields : Map[String, Json] = {
    "chargingRateUnit": Json::string(rate_unit_name(self.charging_rate_unit)),
    "chargingSchedulePeriod": Json::array(
      self.periods.map(fn(period) { period.to_json() }),
    ),
  }
  set_optional_string(fields, "startSchedule", self.start_schedule)
  match self.duration {
    Some(value) => fields.set("duration", int_json(value))
    None => ()
  }
  match self.min_charging_rate {
    Some(value) => fields.set("minChargingRate", Json::number(value))
    None => ()
  }
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ChargingProfile {
  charging_profile_id : Int32
  transaction_id : Int32?
  stack_level : Int32
  charging_profile_purpose : ChargingProfilePurpose
  charging_profile_kind : ChargingProfileKind
  recurrency_kind : String?
  valid_from : String?
  valid_to : String?
  charging_schedule : ChargingSchedule
}

///|
fn parse_charging_profile(
  value : Json,
) -> ChargingProfile raise ProtocolFailure {
  let profile = {
    charging_profile_id: required_nonnegative_int(value, "chargingProfileId"),
    transaction_id: optional_nonnegative_int(value, "transactionId"),
    stack_level: required_nonnegative_int(value, "stackLevel"),
    charging_profile_purpose: parse_profile_purpose(
      required_string(value, "chargingProfilePurpose"),
    ),
    charging_profile_kind: parse_profile_kind(
      required_string(value, "chargingProfileKind"),
    ),
    recurrency_kind: optional_string(value, "recurrencyKind"),
    valid_from: optional_string(value, "validFrom"),
    valid_to: optional_string(value, "validTo"),
    charging_schedule: parse_charging_schedule(
      required_object(value, "chargingSchedule"),
    ),
  }
  let max_profile_has_transaction = profile.charging_profile_purpose ==
    ChargePointMaxProfile &&
    profile.transaction_id is Some(_)
  if max_profile_has_transaction {
    refuse(InvalidField("transactionId"))
  }
  profile
}

///|
pub fn ChargingProfile::from_json(
  value : Json,
) -> Result[ChargingProfile, ProtocolError] {
  result_of(() => parse_charging_profile(value))
}

///|
pub fn ChargingProfile::to_json(self : ChargingProfile) -> Json {
  let fields : Map[String, Json] = {
    "chargingProfileId": int_json(self.charging_profile_id),
    "stackLevel": int_json(self.stack_level),
    "chargingProfilePurpose": Json::string(
      match self.charging_profile_purpose {
        ChargePointMaxProfile => "ChargePointMaxProfile"
        TxDefaultProfile => "TxDefaultProfile"
        TxProfile => "TxProfile"
      },
    ),
    "chargingProfileKind": Json::string(
      match self.charging_profile_kind {
        Absolute => "Absolute"
        Recurring => "Recurring"
        Relative => "Relative"
      },
    ),
    "chargingSchedule": self.charging_schedule.to_json(),
  }
  match self.transaction_id {
    Some(value) => fields.set("transactionId", int_json(value))
    None => ()
  }
  set_optional_string(fields, "recurrencyKind", self.recurrency_kind)
  set_optional_string(fields, "validFrom", self.valid_from)
  set_optional_string(fields, "validTo", self.valid_to)
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum ChargingProfileError {
  NoActiveProfile
  RateUnitMismatch
  InvalidElapsedTime
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ChargingDecision {
  limit : Double
  unit : ChargingRateUnit
  profile_id : Int32
  capped_by_charge_point_max : Bool
}

///|
fn active_limit(profile : ChargingProfile, elapsed_seconds : Int32) -> Double? {
  let schedule = profile.charging_schedule
  let duration = schedule.duration
  if duration is Some(duration) && elapsed_seconds >= duration {
    return None
  }
  let mut selected : Double? = None
  for period in schedule.periods {
    if period.start_period <= elapsed_seconds {
      selected = Some(period.limit)
    } else {
      break
    }
  }
  selected
}

///|
fn choose_highest_stack(
  profiles : Array[ChargingProfile],
  purpose : ChargingProfilePurpose,
  transaction_id : Int32?,
  elapsed_seconds : Int32,
) -> ChargingProfile? {
  let mut selected : ChargingProfile? = None
  for profile in profiles {
    let wrong_purpose = profile.charging_profile_purpose != purpose
    let inactive = active_limit(profile, elapsed_seconds) is None
    let wrong_transaction = purpose == TxProfile &&
      profile.transaction_id != transaction_id
    let max_profile_has_transaction = purpose == ChargePointMaxProfile &&
      profile.transaction_id is Some(_)
    if wrong_purpose ||
      inactive ||
      wrong_transaction ||
      max_profile_has_transaction {
      continue
    }
    selected = Some(
      match selected {
        Some(current) if current.stack_level > profile.stack_level => current
        _ => profile
      },
    )
  }
  selected
}

///|
/// Selects the active transaction profile and applies the active charge-point
/// maximum profile as a cap. `elapsed_seconds` is measured from each profile's
/// own schedule start; the caller owns wall-clock and time-zone handling.
pub fn evaluate_charging_profiles(
  profiles : Array[ChargingProfile],
  transaction_id : Int32?,
  elapsed_seconds : Int32,
) -> Result[ChargingDecision, ChargingProfileError] {
  if elapsed_seconds < 0 {
    return Err(InvalidElapsedTime)
  }
  let transaction_profile = match
    choose_highest_stack(profiles, TxProfile, transaction_id, elapsed_seconds) {
    Some(profile) => Some(profile)
    None =>
      choose_highest_stack(
        profiles,
        TxDefaultProfile,
        transaction_id,
        elapsed_seconds,
      )
  }
  let maximum = choose_highest_stack(
    profiles,
    ChargePointMaxProfile,
    transaction_id,
    elapsed_seconds,
  )
  let base = match transaction_profile {
    Some(profile) => profile
    None =>
      match maximum {
        Some(profile) => profile
        None => return Err(NoActiveProfile)
      }
  }
  let base_limit = match active_limit(base, elapsed_seconds) {
    Some(limit) => limit
    None => return Err(NoActiveProfile)
  }
  let unit = base.charging_schedule.charging_rate_unit
  match maximum {
    Some(maximum_profile) => {
      if maximum_profile.charging_schedule.charging_rate_unit != unit {
        return Err(RateUnitMismatch)
      }
      let maximum_limit = match active_limit(maximum_profile, elapsed_seconds) {
        Some(limit) => limit
        None => return Err(NoActiveProfile)
      }
      if maximum_limit < base_limit {
        Ok({
          limit: maximum_limit,
          unit,
          profile_id: base.charging_profile_id,
          capped_by_charge_point_max: true,
        })
      } else {
        Ok({
          limit: base_limit,
          unit,
          profile_id: base.charging_profile_id,
          capped_by_charge_point_max: false,
        })
      }
    }
    None =>
      Ok({
        limit: base_limit,
        unit,
        profile_id: base.charging_profile_id,
        capped_by_charge_point_max: false,
      })
  }
}
