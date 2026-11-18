///|
fn main raise {
  let frame = match
    @mooncharge.parse_frame(
      "[2,\"boot-1\",\"BootNotification\",{\"chargePointVendor\":\"MoonCharge\",\"chargePointModel\":\"Demo-1\"}]",
    ) {
    Ok(frame) => frame
    Err(error) => fail(error.message())
  }
  let request = match frame {
    @mooncharge.Call(_, _, payload) =>
      match @mooncharge.BootNotificationRequest::from_json(payload) {
        Ok(request) => request
        Err(error) => fail(error.message())
      }
    _ => fail("expected CALL")
  }
  println(
    "vendor=\{request.charge_point_vendor} model=\{request.charge_point_model} frame=\{frame.encode()}",
  )
}
