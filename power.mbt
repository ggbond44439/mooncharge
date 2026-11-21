///|
#derive(Eq, @debug.Debug)
pub(all) enum ElectricalSystem {
  DirectCurrent
  SinglePhaseAc
  ThreePhaseLineToLineAc
  ThreePhaseLineToNeutralAc
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum PowerConversionError {
  InvalidVoltage(Double)
  InvalidPowerFactor(Double)
  PhaseCountMismatch(Int32, Int32)
  NegativeLimit(Double)
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ElectricalModel {
  system : ElectricalSystem
  voltage : Double
  power_factor : Double
}

///|
pub fn ElectricalModel::new(
  system : ElectricalSystem,
  voltage : Double,
  power_factor~ : Double = 1.0,
) -> Result[ElectricalModel, PowerConversionError] {
  if !(voltage > 0.0) {
    return Err(InvalidVoltage(voltage))
  }
  if !(power_factor > 0.0 && power_factor <= 1.0) {
    return Err(InvalidPowerFactor(power_factor))
  }
  Ok({ system, voltage, power_factor, })
}

///|
pub fn ElectricalModel::phase_count(self : ElectricalModel) -> Int32 {
  match self.system {
    DirectCurrent | SinglePhaseAc => 1
    ThreePhaseLineToLineAc | ThreePhaseLineToNeutralAc => 3
  }
}

///|
fn validate_phases(
  model : ElectricalModel,
  number_phases : Int32?,
) -> Result[Unit, PowerConversionError] {
  match number_phases {
    Some(value) =>
      if value == model.phase_count() {
        Ok(())
      } else {
        Err(PhaseCountMismatch(model.phase_count(), value))
      }
    None => Ok(())
  }
}

///|
pub fn ElectricalModel::watts_per_amp(
  self : ElectricalModel,
  number_phases : Int32?,
) -> Result[Double, PowerConversionError] {
  match validate_phases(self, number_phases) {
    Err(error) => Err(error)
    Ok(_) => {
      let factor = match self.system {
        DirectCurrent => self.voltage
        SinglePhaseAc => self.voltage * self.power_factor
        ThreePhaseLineToLineAc => self.voltage * self.power_factor * 3.0.sqrt()
        ThreePhaseLineToNeutralAc => 3.0 * self.voltage * self.power_factor
      }
      Ok(factor)
    }
  }
}

///|
pub fn amps_to_watts(
  amps : Double,
  model : ElectricalModel,
  number_phases~ : Int32? = None,
) -> Result[Double, PowerConversionError] {
  if amps < 0.0 {
    return Err(NegativeLimit(amps))
  }
  let factor = match model.watts_per_amp(number_phases) {
    Ok(factor) => factor
    Err(error) => return Err(error)
  }
  Ok(amps * factor)
}

///|
pub fn watts_to_amps(
  watts : Double,
  model : ElectricalModel,
  number_phases~ : Int32? = None,
) -> Result[Double, PowerConversionError] {
  if watts < 0.0 {
    return Err(NegativeLimit(watts))
  }
  let factor = match model.watts_per_amp(number_phases) {
    Ok(factor) => factor
    Err(error) => return Err(error)
  }
  Ok(watts / factor)
}

///|
pub fn convert_power_limit(
  limit : Double,
  from_unit : ChargingRateUnit,
  target_unit : ChargingRateUnit,
  model : ElectricalModel,
  number_phases~ : Int32? = None,
) -> Result[Double, PowerConversionError] {
  match (from_unit, target_unit) {
    (Amps, Watts) => amps_to_watts(limit, model, number_phases~)
    (Watts, Amps) => watts_to_amps(limit, model, number_phases~)
    _ =>
      match validate_phases(model, number_phases) {
        Ok(_) => Ok(limit)
        Err(error) => Err(error)
      }
  }
}

///|
pub fn normalize_charging_decision(
  decision : ChargingDecision,
  target_unit : ChargingRateUnit,
  model : ElectricalModel,
) -> Result[ChargingDecision, PowerConversionError] {
  let limit = match
    convert_power_limit(
      decision.limit,
      decision.unit,
      target_unit,
      model,
      number_phases=decision.number_phases,
    ) {
    Ok(limit) => limit
    Err(error) => return Err(error)
  }
  Ok({ ..decision, limit, unit: target_unit, })
}
