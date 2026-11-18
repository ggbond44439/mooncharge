///|
fn main {
  let raw_args = @env.args()
  let args : Array[String] = []
  let start = if raw_args.length() > 1 && raw_args[0].has_suffix(".js") {
    2
  } else if raw_args.length() > 2 && raw_args[1].has_suffix(".js") {
    2
  } else {
    1
  }
  for index in start..<raw_args.length() {
    args.push(raw_args[index])
  }
  let output = @mooncharge.run_cli(args)
  if output.stdout != "" {
    println(output.stdout)
  }
  if output.stderr != "" {
    eprintln(output.stderr)
  }
  if output.exit_code != 0 {
    terminate(output.exit_code)
  }
}
