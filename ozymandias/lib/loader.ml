external prog_load : bytes -> int = "ozy_prog_load"
external test_run : int -> int = "ozy_prog_test_run"
external close : int -> unit = "ozy_close"

let load insns = prog_load (Ebpf.assemble insns)

let run insns =
  let fd = load insns in
  Fun.protect ~finally:(fun () -> close fd) (fun () -> test_run fd)
