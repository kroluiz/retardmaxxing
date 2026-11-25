open Ebpf

let run e =
  let code = Codegen.compile e in
  let lo = Loader.run (code @ [ Exit ]) in
  let hi = Loader.run (code @ [ Alu (Rsh, R0, Imm 32l); Exit ]) in
  Int64.logor (Int64.of_int lo) (Int64.shift_left (Int64.of_int hi) 32)
