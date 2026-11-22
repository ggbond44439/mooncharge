///|
fn payload(text : String) -> Json raise {
  match @mooncharge.parse_frame(text) {
    Ok(@mooncharge.Call(_, _, value)) | Ok(@mooncharge.CallResult(_, value)) =>
      value
    _ => fail("expected a JSON-RPC frame")
  }
}

///|
fn certificate_type(value : @mooncharge.CertificateUse) -> String {
  match value {
    @mooncharge.CertificateUse::CentralSystemRootCertificate =>
      "CentralSystemRootCertificate"
    @mooncharge.CertificateUse::ManufacturerRootCertificate =>
      "ManufacturerRootCertificate"
  }
}

///|
fn install_status(value : @mooncharge.InstallCertificateStatus) -> String {
  match value {
    @mooncharge.InstallCertificateStatus::Accepted => "Accepted"
    @mooncharge.InstallCertificateStatus::Failed => "Failed"
    @mooncharge.InstallCertificateStatus::Rejected => "Rejected"
  }
}

///|
fn hash_algorithm(value : @mooncharge.CertificateHashAlgorithm) -> String {
  match value {
    @mooncharge.CertificateHashAlgorithm::SHA256 => "SHA256"
    @mooncharge.CertificateHashAlgorithm::SHA384 => "SHA384"
    @mooncharge.CertificateHashAlgorithm::SHA512 => "SHA512"
  }
}

///|
fn main raise {
  let install = match
    @mooncharge.InstallCertificateRequest::from_json(
      payload(
        "[2,\"install-1\",\"InstallCertificate\",{\"certificateType\":\"CentralSystemRootCertificate\",\"certificate\":\"root-certificate\"}]",
      ),
    ) {
    Ok(request) => request
    Err(_) => fail("failed to parse certificate installation")
  }
  let install_response = match
    @mooncharge.InstallCertificateResponse::from_json(
      payload("[3,\"install-1\",{\"status\":\"Accepted\"}]"),
    ) {
    Ok(response) => response
    Err(_) => fail("failed to parse certificate installation response")
  }
  println(
    "install_type=\{certificate_type(install.certificate_type)} status=\{install_status(install_response.status)}",
  )
  let sign = match
    @mooncharge.SignCertificateRequest::from_json(
      payload(
        "[2,\"sign-1\",\"SignCertificate\",{\"csr\":\"-----BEGIN CERTIFICATE REQUEST-----\"}]",
      ),
    ) {
    Ok(request) => request
    Err(_) => fail("failed to parse certificate signing request")
  }
  let signed = match
    @mooncharge.CertificateSignedRequest::from_json(
      payload(
        "[2,\"signed-1\",\"CertificateSigned\",{\"certificateChain\":\"leaf,root\"}]",
      ),
    ) {
    Ok(request) => request
    Err(_) => fail("failed to parse signed certificate chain")
  }
  println("csr_length=\{sign.csr.length()} chain=\{signed.certificate_chain}")
  let delete = match
    @mooncharge.DeleteCertificateRequest::from_json(
      payload(
        "[2,\"delete-1\",\"DeleteCertificate\",{\"certificateHashData\":{\"hashAlgorithm\":\"SHA256\",\"issuerNameHash\":\"name\",\"issuerKeyHash\":\"key\",\"serialNumber\":\"01A2B3\"}}]",
      ),
    ) {
    Ok(request) => request
    Err(_) => fail("failed to parse certificate deletion")
  }
  println(
    "delete_algorithm=\{hash_algorithm(delete.certificate_hash_data.hash_algorithm)} serial=\{delete.certificate_hash_data.serial_number}",
  )
}
