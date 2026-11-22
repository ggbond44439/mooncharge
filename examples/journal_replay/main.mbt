///|
fn frame(text : String) -> @mooncharge.Frame raise {
  match @mooncharge.parse_frame(text) {
    Ok(frame) => frame
    Err(_) => fail("failed to parse frame")
  }
}

///|
fn direction_name(value : @mooncharge.JournalDirection) -> String {
  match value {
    @mooncharge.JournalDirection::Inbound => "inbound"
    @mooncharge.JournalDirection::Outbound => "outbound"
  }
}

///|
fn frame_label(value : @mooncharge.Frame) -> String {
  match value {
    @mooncharge.Call(_, action, _) => action
    @mooncharge.CallResult(_, _) => "result"
    @mooncharge.CallError(_, _) => "error"
  }
}

///|
fn main raise {
  let journal = match @mooncharge.ProtocolJournal::new(16) {
    Ok(journal) => journal
    Err(_) => fail("failed to create journal")
  }
  ignore(
    journal
    .append(
      1_700_000_000_000L,
      @mooncharge.JournalDirection::Inbound,
      frame("[2,\"hb-1\",\"Heartbeat\",{}]"),
    )
    .unwrap(),
  )
  ignore(
    journal
    .append(
      1_700_000_000_100L,
      @mooncharge.JournalDirection::Outbound,
      frame("[3,\"hb-1\",{\"currentTime\":\"2026-11-22T12:00:00Z\"}]"),
    )
    .unwrap(),
  )
  let saved = journal.to_json_text()
  let restored = match @mooncharge.load_journal(saved) {
    Ok(restored) => restored
    Err(_) => fail("failed to restore journal")
  }
  let replay = restored.replay()
  let first = replay[0]
  let last = replay[replay.length() - 1]
  println(
    "entries=\{restored.entry_count()} first=\{first.sequence} last=\{last.sequence} stable=\{restored == journal}",
  )
  for entry in replay {
    println(
      "sequence=\{entry.sequence} direction=\{direction_name(entry.direction)} action=\{frame_label(entry.frame)}",
    )
  }
}
