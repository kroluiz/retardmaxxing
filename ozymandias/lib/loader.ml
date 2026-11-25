external prog_load : bytes -> int = "ozy_prog_load"
external close : int -> unit = "ozy_close"

let load insns = prog_load (Ebpf.assemble insns)
