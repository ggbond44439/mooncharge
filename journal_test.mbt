///|
fn journal_frame(text : String) -> @mooncharge.Frame raise {
  match @mooncharge.parse_frame(text) {
    Ok(frame) => frame
    Err(_) => fail("failed to parse journal test frame")
  }
}

///|
test "protocol journal assigns sequences and evicts oldest entries" {
  let journal = @mooncharge.ProtocolJournal::new(2).unwrap()
  let first = journal_frame("[2,\"hb-1\",\"Heartbeat\",{}]")
  let second = journal_frame(
    "[3,\"hb-1\",{\"currentTime\":\"2026-11-22T12:00:00Z\"}]",
  )
  let third = journal_frame(
    "[2,\"auth-1\",\"Authorize\",{\"idTag\":\"RFID-1\"}]",
  )
  assert_eq(
    journal.append(1_000, @mooncharge.JournalDirection::Inbound, first),
    Ok(1L),
  )
  assert_eq(
    journal.append(1_010, @mooncharge.JournalDirection::Outbound, second),
    Ok(2L),
  )
  assert_eq(
    journal.append(1_020, @mooncharge.JournalDirection::Inbound, third),
    Ok(3L),
  )
  assert_eq(journal.entry_count(), 2)
  let replay = journal.replay()
  assert_eq(replay[0].sequence, 2L)
  assert_eq(replay[1].sequence, 3L)
  assert_eq(replay[0].direction, @mooncharge.JournalDirection::Outbound)
  assert_eq(
    journal.replay_direction(@mooncharge.JournalDirection::Inbound)[0].frame,
    third,
  )
}

///|
test "protocol journal rejects capacity and timestamp regressions" {
  assert_eq(
    @mooncharge.ProtocolJournal::new(0),
    Err(@mooncharge.JournalError::InvalidCapacity(0)),
  )
  let journal = @mooncharge.ProtocolJournal::new(4).unwrap()
  ignore(
    journal
    .append(
      5_000,
      @mooncharge.JournalDirection::Inbound,
      journal_frame("[2,\"hb-1\",\"Heartbeat\",{}]"),
    )
    .unwrap(),
  )
  assert_eq(
    journal.append(
      4_999,
      @mooncharge.JournalDirection::Outbound,
      journal_frame("[3,\"hb-1\",{\"currentTime\":\"2026-11-22T12:00:00Z\"}]"),
    ),
    Err(@mooncharge.JournalError::TimestampRegression(5_000, 4_999)),
  )
  assert_eq(
    journal.append(
      5_000,
      @mooncharge.JournalDirection::Outbound,
      journal_frame("[3,\"hb-1\",{\"currentTime\":\"2026-11-22T12:00:00Z\"}]"),
    ),
    Ok(2L),
  )
}

///|
test "protocol journal round-trips through versioned JSON" {
  let journal = @mooncharge.ProtocolJournal::new(8).unwrap()
  ignore(
    journal
    .append(
      1_700_000_000_000,
      @mooncharge.JournalDirection::Inbound,
      journal_frame("[2,\"hb-1\",\"Heartbeat\",{}]"),
    )
    .unwrap(),
  )
  ignore(
    journal
    .append(
      1_700_000_000_100,
      @mooncharge.JournalDirection::Outbound,
      journal_frame("[3,\"hb-1\",{\"currentTime\":\"2026-11-22T12:00:00Z\"}]"),
    )
    .unwrap(),
  )
  let text = journal.to_json_text()
  let loaded = @mooncharge.load_journal(text)
  assert_eq(loaded, Ok(journal))
  let restored = loaded.unwrap()
  assert_eq(restored, journal)
  assert_eq(restored.entry_count(), 2)
  assert_eq(restored.replay()[1].timestamp_ms, 1_700_000_000_100L)
}

///|
test "journal loader rejects malformed documents and frames" {
  assert_eq(
    @mooncharge.load_journal("{"),
    Err(@mooncharge.JournalError::InvalidJson),
  )
  assert_eq(
    @mooncharge.load_journal(
      "{\"schemaVersion\":2,\"capacity\":1,\"nextSequence\":\"1\",\"lastTimestampMs\":null,\"entries\":[]}",
    ),
    Err(@mooncharge.JournalError::UnsupportedSchema(2)),
  )
  assert_eq(
    @mooncharge.load_journal(
      "{\"schemaVersion\":1,\"capacity\":1,\"nextSequence\":\"2\",\"lastTimestampMs\":\"1000\",\"entries\":[{\"sequence\":\"1\",\"timestampMs\":\"1000\",\"direction\":\"inbound\",\"frame\":\"{}\"}]}",
    ),
    Err(
      @mooncharge.JournalError::InvalidFrame(
        @mooncharge.ProtocolError::FrameMustBeArray,
      ),
    ),
  )
  assert_eq(
    @mooncharge.load_journal(
      "{\"schemaVersion\":1,\"capacity\":2,\"nextSequence\":\"3\",\"lastTimestampMs\":\"1000\",\"entries\":[{\"sequence\":\"2\",\"timestampMs\":\"900\",\"direction\":\"inbound\",\"frame\":\"[2,\\\"hb\\\",\\\"Heartbeat\\\",{}]\"},{\"sequence\":\"1\",\"timestampMs\":\"1000\",\"direction\":\"outbound\",\"frame\":\"[3,\\\"hb\\\",{}]\"}]}",
    ),
    Err(@mooncharge.JournalError::InvalidField("sequence")),
  )
}

///|
test "clearing a journal resets sequence and replay state" {
  let journal = @mooncharge.ProtocolJournal::new(2).unwrap()
  ignore(
    journal
    .append(
      10,
      @mooncharge.JournalDirection::Inbound,
      journal_frame("[2,\"hb-clear\",\"Heartbeat\",{}]"),
    )
    .unwrap(),
  )
  journal.clear()
  assert_eq(journal.entry_count(), 0)
  assert_eq(journal.replay().length(), 0)
  assert_eq(
    journal.append(
      1,
      @mooncharge.JournalDirection::Inbound,
      journal_frame("[2,\"hb-new\",\"Heartbeat\",{}]"),
    ),
    Ok(1L),
  )
}
