///|
pub(all) struct CliOutput {
  stdout : String
  stderr : String
  exit_code : Int32
}

///|
fn usage() -> String {
  (
    #|mooncharge frame <ocpp-json-frame>
    #|mooncharge action <ActionName> <request|confirmation>
    #|mooncharge dispatch <cp|cs> <ocpp-json-frame>
    #|mooncharge profile <profile-json|profile-array-json> <elapsed-seconds> [transaction-id]
  )
}

///|
fn cli_ok(stdout : String) -> CliOutput {
  { stdout, stderr: "", exit_code: 0, }
}

///|
fn cli_error(message : String) -> CliOutput {
  { stdout: "", stderr: message, exit_code: 2, }
}

///|
fn message_id_text(id : MessageId) -> String {
  match id {
    Text(value) => value
    Number(repr) => repr
    Null => "null"
  }
}

///|
fn frame_summary(frame : Frame) -> String {
  match frame {
    Call(id, action, _) =>
      "kind=call id=\{message_id_text(id)} action=\{action}"
    CallResult(id, _) => "kind=result id=\{message_id_text(id)}"
    CallError(id, error) =>
      "kind=error id=\{message_id_text(id)} code=\{error.code.to_string()}"
  }
}

///|
fn direction_name(direction : MessageDirection) -> String {
  match direction {
    ChargePointToCentralSystem => "charge-point-to-central-system"
    CentralSystemToChargePoint => "central-system-to-charge-point"
  }
}

///|
pub fn run_cli(args : Array[String]) -> CliOutput {
  if args.is_empty() || args[0] == "help" || args[0] == "--help" {
    return cli_ok(usage())
  }
  match args[0] {
    "frame" =>
      if args.length() != 2 {
        cli_error("frame expects exactly one JSON frame")
      } else {
        match parse_frame(args[1]) {
          Ok(frame) => cli_ok(frame_summary(frame))
          Err(error) => cli_error(error.message())
        }
      }
    "action" =>
      if args.length() != 3 ||
        (args[2] != "request" && args[2] != "confirmation") {
        cli_error("action expects <ActionName> <request|confirmation>")
      } else {
        match action_direction(args[1], args[2] == "request") {
          Ok(direction) => cli_ok(direction_name(direction))
          Err(error) => cli_error(error.message())
        }
      }
    "dispatch" =>
      if args.length() != 3 || (args[1] != "cp" && args[1] != "cs") {
        cli_error("dispatch expects <cp|cs> <ocpp-json-frame>")
      } else {
        let direction = if args[1] == "cp" {
          ChargePointToCentralSystem
        } else {
          CentralSystemToChargePoint
        }
        match parse_frame(args[2]) {
          Ok(frame) =>
            match dispatch_call(frame, direction) {
              Ok(call) =>
                cli_ok(
                  "typed=\{call.action_name()} direction=\{direction_name(direction)}",
                )
              Err(NotACall) => cli_error("dispatch requires a CALL frame")
              Err(WrongDirection(expected, actual)) =>
                cli_error(
                  "wrong direction: expected \{direction_name(expected)}, got \{direction_name(actual)}",
                )
              Err(InvalidAction(error) | InvalidPayload(error)) =>
                cli_error(error.message())
            }
          Err(error) => cli_error(error.message())
        }
      }
    "profile" => run_profile_cli(args)
    other => cli_error("unknown command '\{other}'\n\{usage()}")
  }
}

///|
fn run_profile_cli(args : Array[String]) -> CliOutput {
  if args.length() < 3 || args.length() > 4 {
    return cli_error(
      "profile expects <profile-json|profile-array-json> <elapsed-seconds> [transaction-id]",
    )
  }
  let elapsed = @string.parse_int(args[2]) catch {
    _ => return cli_error("elapsed seconds must be an integer")
  }
  let transaction_id = if args.length() == 4 {
    let parsed = @string.parse_int(args[3]) catch {
      _ => return cli_error("transaction id must be an integer")
    }
    Some(parsed)
  } else {
    None
  }
  let input = @json.parse(args[1], max_nesting_depth=64) catch {
    _ => return cli_error("profile input is not valid JSON")
  }
  let profile_values = match input {
    Json::Array(values) => values
    Json::Object(_) => [input]
    _ => return cli_error("profile input must be an object or array of objects")
  }
  let profiles = []
  for value in profile_values {
    match ChargingProfile::from_json(value) {
      Ok(profile) => profiles.push(profile)
      Err(error) => return cli_error(error.message())
    }
  }
  match evaluate_charging_profiles(profiles, transaction_id, elapsed) {
    Ok(decision) => {
      let unit = match decision.unit {
        Amps => "A"
        Watts => "W"
      }
      cli_ok(
        "limit=\{decision.limit} unit=\{unit} profile=\{decision.profile_id} capped=\{decision.capped_by_charge_point_max}",
      )
    }
    Err(NoActiveProfile) => cli_error("no active charging profile")
    Err(RateUnitMismatch) =>
      cli_error("charge-point and transaction profiles use different units")
    Err(InvalidElapsedTime) => cli_error("invalid elapsed time")
  }
}
