open Ozymandias

let () =
  let source = Sys.argv.(1) in
  let ast = Parser.parse (Lexer.tokenize source) in
  Printf.printf "interp: %Ld\n%!" (Interp.eval [] ast);
  Printf.printf "kernel: %Ld\n" (Kernel.run ast)
