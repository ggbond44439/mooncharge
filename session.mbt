///|
#derive(Eq, @debug.Debug)
pub(all) struct ChargingTransaction {
  transaction_id : Int32
  id_tag : String
  meter_start : Int32
  start_timestamp : String
  meter_stop : Int32?
  stop_timestamp : String?
  stop_reason : StopReason?
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ConnectorSession {
  connector_id : Int32
  status : ChargePointStatus
  transaction : ChargingTransaction?
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum SessionError {
  InvalidConnectorId(Int32)
  TransactionAlreadyActive(Int32)
  NoActiveTransaction(Int32)
  TransactionMismatch(Int32, Int32)
  TransactionIdAlreadyUsed(Int32)
  MeterRegression(Int32, Int32)
  InvalidIdTag
}

///|
pub fn ConnectorSession::new(
  connector_id : Int32,
) -> Result[ConnectorSession, SessionError] {
  if connector_id < 0 {
    Err(InvalidConnectorId(connector_id))
  } else {
    Ok({ connector_id, status: Available, transaction: None, })
  }
}

///|
pub fn ConnectorSession::apply_status(
  self : ConnectorSession,
  status : ChargePointStatus,
) -> ConnectorSession {
  { ..self, status, }
}

///|
pub fn ConnectorSession::begin_transaction(
  self : ConnectorSession,
  transaction_id : Int32,
  id_tag : String,
  meter_start : Int32,
  timestamp : String,
) -> Result[ConnectorSession, SessionError] {
  if id_tag.is_empty() {
    return Err(InvalidIdTag)
  }
  if transaction_id < 0 || meter_start < 0 {
    return Err(TransactionAlreadyActive(transaction_id))
  }
  match self.transaction {
    Some(active) => Err(TransactionAlreadyActive(active.transaction_id))
    None => {
      let transaction = {
        transaction_id,
        id_tag,
        meter_start,
        start_timestamp: timestamp,
        meter_stop: None,
        stop_timestamp: None,
        stop_reason: None,
      }
      Ok({ ..self, status: Preparing, transaction: Some(transaction), })
    }
  }
}

///|
pub fn ConnectorSession::begin_charging(
  self : ConnectorSession,
) -> Result[ConnectorSession, SessionError] {
  match self.transaction {
    Some(_) => Ok({ ..self, status: Charging, })
    None => Err(NoActiveTransaction(self.connector_id))
  }
}

///|
pub fn ConnectorSession::finish_transaction(
  self : ConnectorSession,
  transaction_id : Int32,
  meter_stop : Int32,
  timestamp : String,
  reason : StopReason?,
) -> Result[ConnectorSession, SessionError] {
  let active = match self.transaction {
    Some(active) => active
    None => return Err(NoActiveTransaction(self.connector_id))
  }
  if active.transaction_id != transaction_id {
    return Err(TransactionMismatch(active.transaction_id, transaction_id))
  }
  if meter_stop < active.meter_start {
    return Err(MeterRegression(active.meter_start, meter_stop))
  }
  let completed = {
    ..active,
    meter_stop: Some(meter_stop),
    stop_timestamp: Some(timestamp),
    stop_reason: reason,
  }
  Ok({ ..self, status: Finishing, transaction: Some(completed), })
}

///|
pub fn ConnectorSession::release_transaction(
  self : ConnectorSession,
  transaction_id : Int32,
) -> Result[ConnectorSession, SessionError] {
  let active = match self.transaction {
    Some(active) => active
    None => return Err(NoActiveTransaction(self.connector_id))
  }
  if active.transaction_id != transaction_id {
    return Err(TransactionMismatch(active.transaction_id, transaction_id))
  }
  Ok({ ..self, status: Available, transaction: None, })
}

///|
pub fn ConnectorSession::mark_faulted(
  self : ConnectorSession,
) -> ConnectorSession {
  { ..self, status: Faulted, }
}
