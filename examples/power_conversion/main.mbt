///|
fn main raise {
  let model = match
    @mooncharge.ElectricalModel::new(
      @mooncharge.ElectricalSystem::ThreePhaseLineToLineAc,
      400.0,
      power_factor=0.95,
    ) {
    Ok(model) => model
    Err(_) => fail("invalid electrical model")
  }
  let watts = match
    @mooncharge.amps_to_watts(16.0, model, number_phases=Some(3)) {
    Ok(watts) => watts
    Err(_) => fail("failed to convert current limit")
  }
  let amps = match
    @mooncharge.watts_to_amps(11_000.0, model, number_phases=Some(3)) {
    Ok(amps) => amps
    Err(_) => fail("failed to convert power limit")
  }
  println("16A=\{watts}W 11000W=\{amps}A phases=\{model.phase_count()}")
}
