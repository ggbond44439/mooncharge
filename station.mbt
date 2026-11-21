///|
#derive(Eq, @debug.Debug)
pub(all) enum StationMode {
  Operative
  Inoperative
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ConnectorStatusUpdate {
  connector_id : Int32
  status : ChargePointStatus
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum StationError {
  InvalidConnectorId(Int32)
  DuplicateConnectorId(Int32)
  ConnectorNotFound(Int32)
  ActiveTransactionPreventsRemoval(Int32)
  ActiveTransactionPreventsAvailability(Int32)
  DuplicateStatusUpdate(Int32)
  ConnectorNotFaulted(Int32)
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum StationConsistencyIssue {
  InvalidConnectorId(Int32)
  DuplicateConnectorId(Int32)
  ChargingWithoutTransaction(Int32)
  AvailableWithTransaction(Int32)
  InoperativeWithActiveTransaction(Int32)
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct StationSummary {
  total_connectors : Int32
  available : Int32
  unavailable : Int32
  faulted : Int32
  charging : Int32
  active_transactions : Int32
  station_mode : StationMode
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ChargePointSession {
  mut station_mode : StationMode
  connectors : Array[ConnectorSession]
}

///|
pub fn ChargePointSession::new(
  connector_ids : Array[Int32],
) -> Result[ChargePointSession, StationError] {
  let session : ChargePointSession = {
    station_mode: Operative,
    connectors: [],
  }
  for connector_id in connector_ids {
    match session.add_connector(connector_id) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
  }
  Ok(session)
}

///|
fn connector_index(
  station : ChargePointSession,
  connector_id : Int32,
) -> Int32? {
  for index in 0..<station.connectors.length() {
    if station.connectors[index].connector_id == connector_id {
      return Some(index)
    }
  }
  None
}

///|
pub fn ChargePointSession::connector(
  self : ChargePointSession,
  connector_id : Int32,
) -> ConnectorSession? {
  match connector_index(self, connector_id) {
    Some(index) => Some(self.connectors[index])
    None => None
  }
}

///|
pub fn ChargePointSession::add_connector(
  self : ChargePointSession,
  connector_id : Int32,
) -> Result[Unit, StationError] {
  if connector_id <= 0 {
    return Err(InvalidConnectorId(connector_id))
  }
  if connector_index(self, connector_id) is Some(_) {
    return Err(DuplicateConnectorId(connector_id))
  }
  let connector = match ConnectorSession::new(connector_id) {
    Ok(connector) => connector
    Err(_) => return Err(InvalidConnectorId(connector_id))
  }
  let connector = if self.station_mode == Inoperative {
    connector.apply_status(Unavailable)
  } else {
    connector
  }
  self.connectors.push(connector)
  Ok(())
}

///|
pub fn ChargePointSession::remove_connector(
  self : ChargePointSession,
  connector_id : Int32,
) -> Result[Unit, StationError] {
  let index = match connector_index(self, connector_id) {
    Some(index) => index
    None => return Err(ConnectorNotFound(connector_id))
  }
  if self.connectors[index].transaction is Some(_) {
    return Err(ActiveTransactionPreventsRemoval(connector_id))
  }
  ignore(self.connectors.remove(index))
  Ok(())
}

///|
pub fn ChargePointSession::apply_connector_status(
  self : ChargePointSession,
  connector_id : Int32,
  status : ChargePointStatus,
) -> Result[Unit, StationError] {
  let index = match connector_index(self, connector_id) {
    Some(index) => index
    None => return Err(ConnectorNotFound(connector_id))
  }
  self.connectors[index] = self.connectors[index].apply_status(status)
  Ok(())
}

///|
pub fn ChargePointSession::apply_status_batch(
  self : ChargePointSession,
  updates : Array[ConnectorStatusUpdate],
) -> Result[Unit, StationError] {
  let indexes : Array[Int32] = []
  for update in updates {
    let index = match connector_index(self, update.connector_id) {
      Some(index) => index
      None => return Err(ConnectorNotFound(update.connector_id))
    }
    if indexes.contains(index) {
      return Err(DuplicateStatusUpdate(update.connector_id))
    }
    indexes.push(index)
  }
  for position in 0..<updates.length() {
    let index = indexes[position]
    self.connectors[index] = self.connectors[index].apply_status(
      updates[position].status,
    )
  }
  Ok(())
}

///|
pub fn ChargePointSession::change_availability(
  self : ChargePointSession,
  connector_id : Int32,
  availability : AvailabilityType,
) -> Result[Unit, StationError] {
  if connector_id < 0 {
    return Err(InvalidConnectorId(connector_id))
  }
  let target_ids : Array[Int32] = []
  if connector_id == 0 {
    for connector in self.connectors {
      target_ids.push(connector.connector_id)
    }
  } else if connector_index(self, connector_id) is Some(_) {
    target_ids.push(connector_id)
  } else {
    return Err(ConnectorNotFound(connector_id))
  }
  if availability == Inoperative {
    for target_id in target_ids {
      let connector = match self.connector(target_id) {
        Some(connector) => connector
        None => return Err(ConnectorNotFound(target_id))
      }
      if connector.transaction is Some(_) {
        return Err(ActiveTransactionPreventsAvailability(connector_id))
      }
    }
  }
  for target_id in target_ids {
    let index = match connector_index(self, target_id) {
      Some(index) => index
      None => return Err(ConnectorNotFound(target_id))
    }
    let connector = self.connectors[index]
    match availability {
      Inoperative =>
        if connector.status != Faulted {
          self.connectors[index] = connector.apply_status(Unavailable)
        }
      Operative =>
        if connector.status == Unavailable {
          self.connectors[index] = connector.apply_status(Available)
        }
    }
  }
  if connector_id == 0 {
    self.station_mode = match availability {
      Inoperative => Inoperative
      Operative => Operative
    }
  }
  Ok(())
}

///|
pub fn ChargePointSession::clear_connector_fault(
  self : ChargePointSession,
  connector_id : Int32,
) -> Result[Unit, StationError] {
  let index = match connector_index(self, connector_id) {
    Some(index) => index
    None => return Err(ConnectorNotFound(connector_id))
  }
  let connector = self.connectors[index]
  if connector.status != Faulted {
    return Err(ConnectorNotFaulted(connector_id))
  }
  let recovered_status = match connector.transaction {
    None => Available
    Some(transaction) =>
      match transaction.meter_stop {
        None => Charging
        Some(_) => Finishing
      }
  }
  self.connectors[index] = connector.apply_status(recovered_status)
  Ok(())
}

///|
pub fn ChargePointSession::summary(self : ChargePointSession) -> StationSummary {
  let mut available = 0
  let mut unavailable = 0
  let mut faulted = 0
  let mut charging = 0
  let mut active_transactions = 0
  for connector in self.connectors {
    match connector.status {
      Available => available = available + 1
      Unavailable => unavailable = unavailable + 1
      Faulted => faulted = faulted + 1
      Charging => charging = charging + 1
      _ => ()
    }
    if connector.transaction is Some(_) {
      active_transactions = active_transactions + 1
    }
  }
  {
    total_connectors: self.connectors.length(),
    available,
    unavailable,
    faulted,
    charging,
    active_transactions,
    station_mode: self.station_mode,
  }
}

///|
pub fn ChargePointSession::consistency_issues(
  self : ChargePointSession,
) -> Array[StationConsistencyIssue] {
  let issues : Array[StationConsistencyIssue] = []
  let seen : Array[Int32] = []
  for connector in self.connectors {
    if connector.connector_id <= 0 {
      issues.push(InvalidConnectorId(connector.connector_id))
    }
    if seen.contains(connector.connector_id) {
      issues.push(DuplicateConnectorId(connector.connector_id))
    }
    seen.push(connector.connector_id)
    if connector.status == Charging && connector.transaction is None {
      issues.push(ChargingWithoutTransaction(connector.connector_id))
    }
    if connector.status == Available && connector.transaction is Some(_) {
      issues.push(AvailableWithTransaction(connector.connector_id))
    }
    if self.station_mode == Inoperative && connector.transaction is Some(_) {
      issues.push(InoperativeWithActiveTransaction(connector.connector_id))
    }
  }
  issues
}

///|
pub fn ChargePointSession::is_consistent(self : ChargePointSession) -> Bool {
  self.consistency_issues().is_empty()
}
