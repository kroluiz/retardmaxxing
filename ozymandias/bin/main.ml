open Ozymandias

let () =
  let fd = Loader.load Ebpf.[ Alu (Mov, R0, Imm 42l); Exit ] in
  Printf.printf "loaded, fd %d\ncheck it: sudo bpftool prog list\npress enter to unload\n%!" fd;
  ignore (read_line ());
  Loader.close fd
