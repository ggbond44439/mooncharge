///|
pub(all) struct DataTransferRequest {
  vendor_id : String
  message_id : String?
  data : String?
} derive(Eq, @debug.Debug)

///|
fn parse_data_transfer(
  value : Json,
) -> DataTransferRequest raise ProtocolFailure {
  let vendor_id = required_string(value, "vendorId")
  if vendor_id.is_empty() {
    refuse(InvalidField("vendorId"))
  }
  {
    vendor_id,
    message_id: optional_string(value, "messageId"),
    data: optional_string(value, "data"),
  }
}

///|
pub fn DataTransferRequest::from_json(
  value : Json,
) -> Result[DataTransferRequest, ProtocolError] {
  result_of(() => parse_data_transfer(value))
}

///|
pub fn DataTransferRequest::to_json(self : DataTransferRequest) -> Json {
  let fields : Map[String, Json] = { "vendorId": Json::string(self.vendor_id) }
  set_optional_string(fields, "messageId", self.message_id)
  set_optional_string(fields, "data", self.data)
  Json::object(fields)
}

///|
pub(all) enum DataTransferStatus {
  Accepted
  Rejected
  UnknownMessageId
  UnknownVendorId
} derive(Eq, @debug.Debug)

///|
fn parse_data_transfer_status(
  value : String,
) -> DataTransferStatus raise ProtocolFailure {
  match value {
    "Accepted" => Accepted
    "Rejected" => Rejected
    "UnknownMessageId" => UnknownMessageId
    "UnknownVendorId" => UnknownVendorId
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
fn data_transfer_status_name(value : DataTransferStatus) -> String {
  match value {
    Accepted => "Accepted"
    Rejected => "Rejected"
    UnknownMessageId => "UnknownMessageId"
    UnknownVendorId => "UnknownVendorId"
  }
}

///|
pub(all) struct DataTransferResponse {
  status : DataTransferStatus
  data : String?
} derive(Eq, @debug.Debug)

///|
fn parse_data_transfer_response(
  value : Json,
) -> DataTransferResponse raise ProtocolFailure {
  {
    status: parse_data_transfer_status(required_string(value, "status")),
    data: optional_string(value, "data"),
  }
}

///|
pub fn DataTransferResponse::from_json(
  value : Json,
) -> Result[DataTransferResponse, ProtocolError] {
  result_of(() => parse_data_transfer_response(value))
}

///|
pub fn DataTransferResponse::to_json(self : DataTransferResponse) -> Json {
  let fields : Map[String, Json] = {
    "status": Json::string(data_transfer_status_name(self.status)),
  }
  set_optional_string(fields, "data", self.data)
  Json::object(fields)
}
