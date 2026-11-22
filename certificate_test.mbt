///|
fn certificate_payload(text : String) -> Json raise {
  match @mooncharge.parse_frame(text) {
    Ok(@mooncharge.Call(_, _, payload)) => payload
    Ok(@mooncharge.CallResult(_, payload)) => payload
    _ => fail("expected a frame with an object payload")
  }
}

///|
fn test_certificate_hash() -> @mooncharge.CertificateHashData {
  {
    hash_algorithm: @mooncharge.CertificateHashAlgorithm::SHA256,
    issuer_name_hash: "issuer-name-hash",
    issuer_key_hash: "issuer-key-hash",
    serial_number: "01A2B3",
  }
}

///|
test "certificate signing request and signed chain round-trip" {
  let sign = match
    @mooncharge.SignCertificateRequest::from_json(
      certificate_payload(
        "[2,\"sign-1\",\"SignCertificate\",{\"csr\":\"-----BEGIN CERTIFICATE REQUEST-----\"}]",
      ),
    ) {
    Ok(request) => request
    Err(_) => fail("failed to parse SignCertificate")
  }
  assert_eq(sign.csr, "-----BEGIN CERTIFICATE REQUEST-----")
  assert_eq(
    @mooncharge.SignCertificateRequest::from_json(sign.to_json()),
    Ok(sign),
  )
  assert_eq(
    @mooncharge.SignCertificateResponse::from_json(
      certificate_payload("[3,\"sign-1\",{\"status\":\"Accepted\"}]"),
    ),
    Ok({ status: @mooncharge.SignCertificateStatus::Accepted, }),
  )
  let signed = match
    @mooncharge.CertificateSignedRequest::from_json(
      certificate_payload(
        "[2,\"signed-1\",\"CertificateSigned\",{\"certificateChain\":\"leaf,root\"}]",
      ),
    ) {
    Ok(request) => request
    Err(_) => fail("failed to parse CertificateSigned")
  }
  assert_eq(signed.certificate_chain, "leaf,root")
  assert_eq(
    @mooncharge.CertificateSignedRequest::from_json(signed.to_json()),
    Ok(signed),
  )
  assert_eq(
    @mooncharge.CertificateSignedResponse::from_json(
      certificate_payload("[3,\"signed-1\",{\"status\":\"Rejected\"}]"),
    ),
    Ok({ status: @mooncharge.CertificateSignedStatus::Rejected, }),
  )
}

///|
test "DeleteCertificate preserves all certificate hash fields" {
  let request = match
    @mooncharge.DeleteCertificateRequest::from_json(
      certificate_payload(
        "[2,\"delete-1\",\"DeleteCertificate\",{\"certificateHashData\":{\"hashAlgorithm\":\"SHA256\",\"issuerNameHash\":\"issuer-name-hash\",\"issuerKeyHash\":\"issuer-key-hash\",\"serialNumber\":\"01A2B3\"}}]",
      ),
    ) {
    Ok(request) => request
    Err(_) => fail("failed to parse DeleteCertificate")
  }
  assert_eq(request.certificate_hash_data, test_certificate_hash())
  assert_eq(
    @mooncharge.DeleteCertificateRequest::from_json(request.to_json()),
    Ok(request),
  )
  assert_eq(
    @mooncharge.DeleteCertificateResponse::from_json(
      certificate_payload("[3,\"delete-1\",{\"status\":\"NotFound\"}]"),
    ),
    Ok({ status: @mooncharge.DeleteCertificateStatus::NotFound, }),
  )
}

///|
test "certificate discovery distinguishes root certificate uses" {
  let request = match
    @mooncharge.GetInstalledCertificateIdsRequest::from_json(
      certificate_payload(
        "[2,\"list-1\",\"GetInstalledCertificateIds\",{\"certificateType\":\"ManufacturerRootCertificate\"}]",
      ),
    ) {
    Ok(request) => request
    Err(_) => fail("failed to parse GetInstalledCertificateIds")
  }
  assert_eq(
    request.certificate_type,
    @mooncharge.CertificateUse::ManufacturerRootCertificate,
  )
  assert_eq(
    @mooncharge.GetInstalledCertificateIdsRequest::from_json(request.to_json()),
    Ok(request),
  )
  let response = match
    @mooncharge.GetInstalledCertificateIdsResponse::from_json(
      certificate_payload(
        "[3,\"list-1\",{\"status\":\"Accepted\",\"certificateHashData\":[{\"hashAlgorithm\":\"SHA256\",\"issuerNameHash\":\"issuer-name-hash\",\"issuerKeyHash\":\"issuer-key-hash\",\"serialNumber\":\"01A2B3\"}]}]",
      ),
    ) {
    Ok(response) => response
    Err(_) => fail("failed to parse certificate list")
  }
  assert_eq(
    response.status,
    @mooncharge.GetInstalledCertificateStatus::Accepted,
  )
  assert_eq(response.certificate_hash_data.length(), 1)
  assert_eq(response.certificate_hash_data[0], test_certificate_hash())
  assert_eq(
    @mooncharge.GetInstalledCertificateIdsResponse::from_json(
      response.to_json(),
    ),
    Ok(response),
  )
}

///|
test "certificate installation validates type and certificate material" {
  let request = match
    @mooncharge.InstallCertificateRequest::from_json(
      certificate_payload(
        "[2,\"install-1\",\"InstallCertificate\",{\"certificateType\":\"CentralSystemRootCertificate\",\"certificate\":\"root-certificate\"}]",
      ),
    ) {
    Ok(request) => request
    Err(_) => fail("failed to parse InstallCertificate")
  }
  assert_eq(
    request.certificate_type,
    @mooncharge.CertificateUse::CentralSystemRootCertificate,
  )
  assert_eq(request.certificate, "root-certificate")
  assert_eq(
    @mooncharge.InstallCertificateRequest::from_json(request.to_json()),
    Ok(request),
  )
  assert_eq(
    @mooncharge.InstallCertificateResponse::from_json(
      certificate_payload("[3,\"install-1\",{\"status\":\"Failed\"}]"),
    ),
    Ok({ status: @mooncharge.InstallCertificateStatus::Failed, }),
  )
  assert_eq(
    @mooncharge.InstallCertificateRequest::from_json(
      certificate_payload(
        "[2,\"install-bad\",\"InstallCertificate\",{\"certificateType\":\"LeafCertificate\",\"certificate\":\"root\"}]",
      ),
    ),
    Err(
      @mooncharge.ProtocolError::UnsupportedValue(
        "certificateType", "LeafCertificate",
      ),
    ),
  )
}

///|
test "certificate action dispatch covers both business directions" {
  let install = match
    @mooncharge.parse_frame(
      "[2,\"install-dispatch\",\"InstallCertificate\",{\"certificateType\":\"CentralSystemRootCertificate\",\"certificate\":\"root\"}]",
    ) {
    Ok(frame) => frame
    Err(_) => fail("failed to parse install frame")
  }
  match
    @mooncharge.dispatch_call(
      install,
      @mooncharge.MessageDirection::CentralSystemToChargePoint,
    ) {
    Ok(@mooncharge.TypedCall::InstallCertificate(request)) =>
      assert_eq(request.certificate, "root")
    _ => fail("expected typed InstallCertificate")
  }
  let sign = match
    @mooncharge.parse_frame(
      "[2,\"sign-dispatch\",\"SignCertificate\",{\"csr\":\"csr\"}]",
    ) {
    Ok(frame) => frame
    Err(_) => fail("failed to parse signing frame")
  }
  match
    @mooncharge.dispatch_call(
      sign,
      @mooncharge.MessageDirection::ChargePointToCentralSystem,
    ) {
    Ok(@mooncharge.TypedCall::SignCertificate(request)) =>
      assert_eq(request.csr, "csr")
    _ => fail("expected typed SignCertificate")
  }
}

///|
test "all OCPP 1.6 actions now have typed requests and confirmations" {
  assert_eq(@mooncharge.conformance_summary(), {
    total_actions: 39,
    typed_requests: 39,
    typed_responses: 39,
    catalog_only_requests: 0,
    catalog_only_responses: 0,
  })
  for spec in @mooncharge.action_specs() {
    assert_eq(spec.request_coverage, @mooncharge.PayloadCoverage::Typed)
    assert_eq(spec.response_coverage, @mooncharge.PayloadCoverage::Typed)
  }
}
