///|
#derive(Eq, @debug.Debug)
pub(all) enum CertificateHashAlgorithm {
  SHA256
  SHA384
  SHA512
}

///|
fn parse_certificate_hash_algorithm(
  value : String,
) -> CertificateHashAlgorithm raise ProtocolFailure {
  match value {
    "SHA256" => SHA256
    "SHA384" => SHA384
    "SHA512" => SHA512
    _ => refuse(UnsupportedValue("hashAlgorithm", value))
  }
}

///|
fn certificate_hash_algorithm_name(value : CertificateHashAlgorithm) -> String {
  match value {
    SHA256 => "SHA256"
    SHA384 => "SHA384"
    SHA512 => "SHA512"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct CertificateHashData {
  hash_algorithm : CertificateHashAlgorithm
  issuer_name_hash : String
  issuer_key_hash : String
  serial_number : String
}

///|
fn parse_certificate_hash_data(
  value : Json,
) -> CertificateHashData raise ProtocolFailure {
  {
    hash_algorithm: parse_certificate_hash_algorithm(
      required_string(value, "hashAlgorithm"),
    ),
    issuer_name_hash: required_nonempty_string(value, "issuerNameHash"),
    issuer_key_hash: required_nonempty_string(value, "issuerKeyHash"),
    serial_number: required_nonempty_string(value, "serialNumber"),
  }
}

///|
pub fn CertificateHashData::from_json(
  value : Json,
) -> Result[CertificateHashData, ProtocolError] {
  result_of(() => parse_certificate_hash_data(value))
}

///|
pub fn CertificateHashData::to_json(self : CertificateHashData) -> Json {
  Json::object({
    "hashAlgorithm": Json::string(
      certificate_hash_algorithm_name(self.hash_algorithm),
    ),
    "issuerNameHash": Json::string(self.issuer_name_hash),
    "issuerKeyHash": Json::string(self.issuer_key_hash),
    "serialNumber": Json::string(self.serial_number),
  })
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct CertificateSignedRequest {
  certificate_chain : String
}

///|
fn parse_certificate_signed_request(
  value : Json,
) -> CertificateSignedRequest raise ProtocolFailure {
  { certificate_chain: required_nonempty_string(value, "certificateChain"), }
}

///|
pub fn CertificateSignedRequest::from_json(
  value : Json,
) -> Result[CertificateSignedRequest, ProtocolError] {
  result_of(() => parse_certificate_signed_request(value))
}

///|
pub fn CertificateSignedRequest::to_json(
  self : CertificateSignedRequest,
) -> Json {
  Json::object({ "certificateChain": Json::string(self.certificate_chain) })
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum CertificateSignedStatus {
  Accepted
  Rejected
}

///|
fn parse_certificate_signed_status(
  value : String,
) -> CertificateSignedStatus raise ProtocolFailure {
  match value {
    "Accepted" => Accepted
    "Rejected" => Rejected
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
fn certificate_signed_status_name(value : CertificateSignedStatus) -> String {
  match value {
    Accepted => "Accepted"
    Rejected => "Rejected"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct CertificateSignedResponse {
  status : CertificateSignedStatus
}

///|
fn parse_certificate_signed_response(
  value : Json,
) -> CertificateSignedResponse raise ProtocolFailure {
  { status: parse_certificate_signed_status(required_string(value, "status")), }
}

///|
pub fn CertificateSignedResponse::from_json(
  value : Json,
) -> Result[CertificateSignedResponse, ProtocolError] {
  result_of(() => parse_certificate_signed_response(value))
}

///|
pub fn CertificateSignedResponse::to_json(
  self : CertificateSignedResponse,
) -> Json {
  Json::object({
    "status": Json::string(certificate_signed_status_name(self.status)),
  })
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct DeleteCertificateRequest {
  certificate_hash_data : CertificateHashData
}

///|
fn parse_delete_certificate_request(
  value : Json,
) -> DeleteCertificateRequest raise ProtocolFailure {
  {
    certificate_hash_data: parse_certificate_hash_data(
      required_object(value, "certificateHashData"),
    ),
  }
}

///|
pub fn DeleteCertificateRequest::from_json(
  value : Json,
) -> Result[DeleteCertificateRequest, ProtocolError] {
  result_of(() => parse_delete_certificate_request(value))
}

///|
pub fn DeleteCertificateRequest::to_json(
  self : DeleteCertificateRequest,
) -> Json {
  Json::object({ "certificateHashData": self.certificate_hash_data.to_json() })
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum DeleteCertificateStatus {
  Accepted
  Failed
  NotFound
}

///|
fn parse_delete_certificate_status(
  value : String,
) -> DeleteCertificateStatus raise ProtocolFailure {
  match value {
    "Accepted" => Accepted
    "Failed" => Failed
    "NotFound" => NotFound
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
fn delete_certificate_status_name(value : DeleteCertificateStatus) -> String {
  match value {
    Accepted => "Accepted"
    Failed => "Failed"
    NotFound => "NotFound"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct DeleteCertificateResponse {
  status : DeleteCertificateStatus
}

///|
fn parse_delete_certificate_response(
  value : Json,
) -> DeleteCertificateResponse raise ProtocolFailure {
  { status: parse_delete_certificate_status(required_string(value, "status")), }
}

///|
pub fn DeleteCertificateResponse::from_json(
  value : Json,
) -> Result[DeleteCertificateResponse, ProtocolError] {
  result_of(() => parse_delete_certificate_response(value))
}

///|
pub fn DeleteCertificateResponse::to_json(
  self : DeleteCertificateResponse,
) -> Json {
  Json::object({
    "status": Json::string(delete_certificate_status_name(self.status)),
  })
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum CertificateUse {
  CentralSystemRootCertificate
  ManufacturerRootCertificate
}

///|
fn parse_certificate_use(
  value : String,
) -> CertificateUse raise ProtocolFailure {
  match value {
    "CentralSystemRootCertificate" => CentralSystemRootCertificate
    "ManufacturerRootCertificate" => ManufacturerRootCertificate
    _ => refuse(UnsupportedValue("certificateType", value))
  }
}

///|
fn certificate_use_name(value : CertificateUse) -> String {
  match value {
    CentralSystemRootCertificate => "CentralSystemRootCertificate"
    ManufacturerRootCertificate => "ManufacturerRootCertificate"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct GetInstalledCertificateIdsRequest {
  certificate_type : CertificateUse
}

///|
fn parse_get_installed_certificate_ids_request(
  value : Json,
) -> GetInstalledCertificateIdsRequest raise ProtocolFailure {
  {
    certificate_type: parse_certificate_use(
      required_string(value, "certificateType"),
    ),
  }
}

///|
pub fn GetInstalledCertificateIdsRequest::from_json(
  value : Json,
) -> Result[GetInstalledCertificateIdsRequest, ProtocolError] {
  result_of(() => parse_get_installed_certificate_ids_request(value))
}

///|
pub fn GetInstalledCertificateIdsRequest::to_json(
  self : GetInstalledCertificateIdsRequest,
) -> Json {
  Json::object({
    "certificateType": Json::string(certificate_use_name(self.certificate_type)),
  })
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum GetInstalledCertificateStatus {
  Accepted
  NotFound
}

///|
fn parse_installed_certificate_status(
  value : String,
) -> GetInstalledCertificateStatus raise ProtocolFailure {
  match value {
    "Accepted" => Accepted
    "NotFound" => NotFound
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
fn installed_certificate_status_name(
  value : GetInstalledCertificateStatus,
) -> String {
  match value {
    Accepted => "Accepted"
    NotFound => "NotFound"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct GetInstalledCertificateIdsResponse {
  status : GetInstalledCertificateStatus
  certificate_hash_data : Array[CertificateHashData]
}

///|
fn parse_get_installed_certificate_ids_response(
  value : Json,
) -> GetInstalledCertificateIdsResponse raise ProtocolFailure {
  let fields = match value {
    Json::Object(fields) => fields
    _ => refuse(InvalidPayload)
  }
  let hashes = match fields.get("certificateHashData") {
    None | Some(Json::Null) => []
    Some(field) => {
      let items = match field {
        Json::Array(items) if !items.is_empty() => items
        _ => refuse(InvalidField("certificateHashData"))
      }
      let values = []
      for item in items {
        values.push(parse_certificate_hash_data(item))
      }
      values
    }
  }
  {
    status: parse_installed_certificate_status(required_string(value, "status")),
    certificate_hash_data: hashes,
  }
}

///|
pub fn GetInstalledCertificateIdsResponse::from_json(
  value : Json,
) -> Result[GetInstalledCertificateIdsResponse, ProtocolError] {
  result_of(() => parse_get_installed_certificate_ids_response(value))
}

///|
pub fn GetInstalledCertificateIdsResponse::to_json(
  self : GetInstalledCertificateIdsResponse,
) -> Json {
  let fields : Map[String, Json] = {
    "status": Json::string(installed_certificate_status_name(self.status)),
  }
  if !self.certificate_hash_data.is_empty() {
    fields.set(
      "certificateHashData",
      Json::array(self.certificate_hash_data.map(fn(value) { value.to_json() })),
    )
  }
  Json::object(fields)
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct InstallCertificateRequest {
  certificate_type : CertificateUse
  certificate : String
}

///|
fn parse_install_certificate_request(
  value : Json,
) -> InstallCertificateRequest raise ProtocolFailure {
  {
    certificate_type: parse_certificate_use(
      required_string(value, "certificateType"),
    ),
    certificate: required_nonempty_string(value, "certificate"),
  }
}

///|
pub fn InstallCertificateRequest::from_json(
  value : Json,
) -> Result[InstallCertificateRequest, ProtocolError] {
  result_of(() => parse_install_certificate_request(value))
}

///|
pub fn InstallCertificateRequest::to_json(
  self : InstallCertificateRequest,
) -> Json {
  Json::object({
    "certificateType": Json::string(certificate_use_name(self.certificate_type)),
    "certificate": Json::string(self.certificate),
  })
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum InstallCertificateStatus {
  Accepted
  Failed
  Rejected
}

///|
fn parse_install_certificate_status(
  value : String,
) -> InstallCertificateStatus raise ProtocolFailure {
  match value {
    "Accepted" => Accepted
    "Failed" => Failed
    "Rejected" => Rejected
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
fn install_certificate_status_name(value : InstallCertificateStatus) -> String {
  match value {
    Accepted => "Accepted"
    Failed => "Failed"
    Rejected => "Rejected"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct InstallCertificateResponse {
  status : InstallCertificateStatus
}

///|
fn parse_install_certificate_response(
  value : Json,
) -> InstallCertificateResponse raise ProtocolFailure {
  {
    status: parse_install_certificate_status(required_string(value, "status")),
  }
}

///|
pub fn InstallCertificateResponse::from_json(
  value : Json,
) -> Result[InstallCertificateResponse, ProtocolError] {
  result_of(() => parse_install_certificate_response(value))
}

///|
pub fn InstallCertificateResponse::to_json(
  self : InstallCertificateResponse,
) -> Json {
  Json::object({
    "status": Json::string(install_certificate_status_name(self.status)),
  })
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct SignCertificateRequest {
  csr : String
}

///|
fn parse_sign_certificate_request(
  value : Json,
) -> SignCertificateRequest raise ProtocolFailure {
  { csr: required_nonempty_string(value, "csr"), }
}

///|
pub fn SignCertificateRequest::from_json(
  value : Json,
) -> Result[SignCertificateRequest, ProtocolError] {
  result_of(() => parse_sign_certificate_request(value))
}

///|
pub fn SignCertificateRequest::to_json(self : SignCertificateRequest) -> Json {
  Json::object({ "csr": Json::string(self.csr) })
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum SignCertificateStatus {
  Accepted
  Rejected
}

///|
fn parse_sign_certificate_status(
  value : String,
) -> SignCertificateStatus raise ProtocolFailure {
  match value {
    "Accepted" => Accepted
    "Rejected" => Rejected
    _ => refuse(UnsupportedValue("status", value))
  }
}

///|
fn sign_certificate_status_name(value : SignCertificateStatus) -> String {
  match value {
    Accepted => "Accepted"
    Rejected => "Rejected"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct SignCertificateResponse {
  status : SignCertificateStatus
}

///|
fn parse_sign_certificate_response(
  value : Json,
) -> SignCertificateResponse raise ProtocolFailure {
  { status: parse_sign_certificate_status(required_string(value, "status")), }
}

///|
pub fn SignCertificateResponse::from_json(
  value : Json,
) -> Result[SignCertificateResponse, ProtocolError] {
  result_of(() => parse_sign_certificate_response(value))
}

///|
pub fn SignCertificateResponse::to_json(self : SignCertificateResponse) -> Json {
  Json::object({
    "status": Json::string(sign_certificate_status_name(self.status)),
  })
}
