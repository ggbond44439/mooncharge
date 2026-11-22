///|
#derive(Eq, @debug.Debug)
pub(all) enum JournalDirection {
  Inbound
  Outbound
}

///|
fn journal_direction_name(value : JournalDirection) -> String {
  match value {
    Inbound => "inbound"
    Outbound => "outbound"
  }
}

///|
fn parse_journal_direction(
  value : String,
) -> JournalDirection raise JournalFailure {
  match value {
    "inbound" => Inbound
    "outbound" => Outbound
    _ => journal_refuse(InvalidField("direction"))
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct JournalEntry {
  sequence : Int64
  timestamp_ms : Int64
  direction : JournalDirection
  frame : Frame
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum JournalError {
  InvalidCapacity(Int32)
  TimestampRegression(Int64, Int64)
  InvalidJson
  UnsupportedSchema(Int32)
  MissingField(String)
  InvalidField(String)
  InvalidFrame(ProtocolError)
}

///|
pub(all) suberror JournalFailure {
  Failure(JournalError)
}

///|
fn[T] journal_refuse(error : JournalError) -> T raise JournalFailure {
  raise Failure(error)
}

///|
fn[T] journal_result(
  parse : () -> T raise JournalFailure,
) -> Result[T, JournalError] {
  Ok(parse()) catch {
    Failure(error) => Err(error)
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ProtocolJournal {
  capacity : Int32
  mut next_sequence : Int64
  mut last_timestamp_ms : Int64?
  mut entries : Array[JournalEntry]
}

///|
pub fn ProtocolJournal::new(
  capacity : Int32,
) -> Result[ProtocolJournal, JournalError] {
  if capacity <= 0 {
    Err(InvalidCapacity(capacity))
  } else {
    Ok({ capacity, next_sequence: 1, last_timestamp_ms: None, entries: [], })
  }
}

///|
pub fn ProtocolJournal::append(
  self : ProtocolJournal,
  timestamp_ms : Int64,
  direction : JournalDirection,
  frame : Frame,
) -> Result[Int64, JournalError] {
  match self.last_timestamp_ms {
    Some(previous) if timestamp_ms < previous =>
      Err(TimestampRegression(previous, timestamp_ms))
    _ => {
      if self.entries.length() >= self.capacity {
        ignore(self.entries.remove(0))
      }
      let sequence = self.next_sequence
      self.entries.push({ sequence, timestamp_ms, direction, frame, })
      self.next_sequence = self.next_sequence + 1
      self.last_timestamp_ms = Some(timestamp_ms)
      Ok(sequence)
    }
  }
}

///|
pub fn ProtocolJournal::entry_count(self : ProtocolJournal) -> Int32 {
  self.entries.length()
}

///|
pub fn ProtocolJournal::replay(self : ProtocolJournal) -> Array[JournalEntry] {
  self.entries.map(fn(entry) { entry })
}

///|
pub fn ProtocolJournal::replay_direction(
  self : ProtocolJournal,
  direction : JournalDirection,
) -> Array[JournalEntry] {
  self.entries.filter(fn(entry) { entry.direction == direction })
}

///|
pub fn ProtocolJournal::clear(self : ProtocolJournal) -> Unit {
  self.entries = []
  self.next_sequence = 1
  self.last_timestamp_ms = None
}

///|
fn journal_field(value : Json, name : String) -> Json raise JournalFailure {
  let fields = match value {
    Json::Object(fields) => fields
    _ => journal_refuse(InvalidField("journal"))
  }
  match fields.get(name) {
    Some(field) => field
    None => journal_refuse(MissingField(name))
  }
}

///|
fn journal_required_string(
  value : Json,
  name : String,
) -> String raise JournalFailure {
  match journal_field(value, name) {
    Json::String(text) => text
    _ => journal_refuse(InvalidField(name))
  }
}

///|
fn journal_required_int32(
  value : Json,
  name : String,
) -> Int32 raise JournalFailure {
  match journal_field(value, name) {
    Json::Number(number, ..) => {
      let parsed = number.to_int()
      if parsed >= 0 && parsed.to_double() == number {
        parsed
      } else {
        journal_refuse(InvalidField(name))
      }
    }
    _ => journal_refuse(InvalidField(name))
  }
}

///|
fn journal_required_array(
  value : Json,
  name : String,
) -> Array[Json] raise JournalFailure {
  match journal_field(value, name) {
    Json::Array(items) => items
    _ => journal_refuse(InvalidField(name))
  }
}

///|
fn required_int64(value : Json, name : String) -> Int64 raise JournalFailure {
  let text = match journal_field(value, name) {
    Json::String(text) => text
    _ => journal_refuse(InvalidField(name))
  }
  @string.parse_int64(text) catch {
    _ => journal_refuse(InvalidField(name))
  }
}

///|
fn optional_int64(value : Json, name : String) -> Int64? raise JournalFailure {
  match journal_field(value, name) {
    Json::Null => None
    Json::String(text) =>
      Some(
        @string.parse_int64(text) catch {
          _ => journal_refuse(InvalidField(name))
        },
      )
    _ => journal_refuse(InvalidField(name))
  }
}

///|
pub fn ProtocolJournal::to_json(self : ProtocolJournal) -> Json {
  Json::object({
    "schemaVersion": int_json(1),
    "capacity": int_json(self.capacity),
    "nextSequence": Json::string(self.next_sequence.to_string()),
    "lastTimestampMs": match self.last_timestamp_ms {
      Some(value) => Json::string(value.to_string())
      None => Json::null()
    },
    "entries": Json::array(
      self.entries.map(fn(entry) {
        Json::object({
          "sequence": Json::string(entry.sequence.to_string()),
          "timestampMs": Json::string(entry.timestamp_ms.to_string()),
          "direction": Json::string(journal_direction_name(entry.direction)),
          "frame": Json::string(entry.frame.encode()),
        })
      }),
    ),
  })
}

///|
pub fn ProtocolJournal::to_json_text(self : ProtocolJournal) -> String {
  self.to_json().stringify()
}

///|
fn parse_journal_entry(value : Json) -> JournalEntry raise JournalFailure {
  let frame_text = journal_required_string(value, "frame")
  let frame = match parse_frame(frame_text) {
    Ok(frame) => frame
    Err(error) => journal_refuse(InvalidFrame(error))
  }
  {
    sequence: required_int64(value, "sequence"),
    timestamp_ms: required_int64(value, "timestampMs"),
    direction: parse_journal_direction(
      journal_required_string(value, "direction"),
    ),
    frame,
  }
}

///|
fn parse_journal_document(value : Json) -> ProtocolJournal raise JournalFailure {
  let schema_version = journal_required_int32(value, "schemaVersion")
  if schema_version != 1 {
    journal_refuse(UnsupportedSchema(schema_version))
  }
  let capacity = journal_required_int32(value, "capacity")
  if capacity <= 0 {
    journal_refuse(InvalidCapacity(capacity))
  }
  let items = journal_required_array(value, "entries")
  if items.length() > capacity {
    journal_refuse(InvalidField("entries"))
  }
  let entries = []
  let mut previous_sequence = 0L
  let mut previous_timestamp = 0L
  for item in items {
    let entry = parse_journal_entry(item)
    if entry.sequence <= previous_sequence ||
      (!entries.is_empty() && entry.sequence != previous_sequence + 1) {
      journal_refuse(InvalidField("sequence"))
    }
    if !entries.is_empty() && entry.timestamp_ms < previous_timestamp {
      journal_refuse(InvalidField("timestampMs"))
    }
    previous_sequence = entry.sequence
    previous_timestamp = entry.timestamp_ms
    entries.push(entry)
  }
  let next_sequence = required_int64(value, "nextSequence")
  if next_sequence <= previous_sequence {
    journal_refuse(InvalidField("nextSequence"))
  }
  let last_timestamp_ms = optional_int64(value, "lastTimestampMs")
  if entries.is_empty() {
    if last_timestamp_ms is Some(_) {
      journal_refuse(InvalidField("lastTimestampMs"))
    }
  } else {
    match last_timestamp_ms {
      Some(timestamp) if timestamp != previous_timestamp =>
        journal_refuse(InvalidField("lastTimestampMs"))
      None => journal_refuse(InvalidField("lastTimestampMs"))
      _ => ()
    }
  }
  { capacity, next_sequence, last_timestamp_ms, entries, }
}

///|
pub fn load_journal(text : String) -> Result[ProtocolJournal, JournalError] {
  journal_result(() => {
    let value = @json.parse(text, max_nesting_depth=64) catch {
      _ => journal_refuse(InvalidJson)
    }
    parse_journal_document(value)
  })
}
