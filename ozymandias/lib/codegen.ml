open Ebpf

let size insns =
  List.fold_left (fun n i -> match i with Lddw _ -> n + 2 | _ -> n + 1) 0 insns

let slot depth =
  let off = -8 * (depth + 1) in
  if off < -512 then failwith "out of stack" else off

let const r n =
  if n >= Int64.of_int32 Int32.min_int && n <= Int64.of_int32 Int32.max_int
  then [ Alu (Mov, r, Imm (Int64.to_int32 n)) ]
  else [ Lddw (r, n) ]

let rec gen env depth e =
  match e with
  | Ast.Int n -> const R0 n
  | Ast.Var name ->
      (match List.assoc_opt name env with
       | Some off -> [ Ldx (R0, R10, off) ]
       | None -> failwith ("unbound variable " ^ name))
  | Ast.Add (a, b) -> binop env depth a b [ Alu (Add, R0, Reg R1) ]
  | Ast.Sub (a, b) -> binop env depth a b [ Alu (Sub, R0, Reg R1) ]
  | Ast.Mul (a, b) -> binop env depth a b [ Alu (Mul, R0, Reg R1) ]
  | Ast.Div (a, b) -> binop env depth a b [ Alu (Sdiv, R0, Reg R1) ]
  | Ast.Lt (a, b) -> cmp env depth Jslt a b
  | Ast.Gt (a, b) -> cmp env depth Jsgt a b
  | Ast.Eq (a, b) -> cmp env depth Jeq a b
  | Ast.Neq (a, b) -> cmp env depth Jne a b
  | Ast.If (c, a, b) ->
      let cc = gen env depth c in
      let ca = gen env depth a in
      let cb = gen env depth b in
      cc @ [ Jmp (Jeq, R0, Imm 0l, size ca + 1) ] @ ca @ [ Ja (size cb) ] @ cb
  | Ast.Let (name, value, body) ->
      let off = slot depth in
      gen env depth value
      @ [ Stx (R10, off, R0) ]
      @ gen ((name, off) :: env) (depth + 1) body

and binop env depth a b op =
  let off = slot depth in
  gen env depth a
  @ [ Stx (R10, off, R0) ]
  @ gen env (depth + 1) b
  @ [ Alu (Mov, R1, Reg R0); Ldx (R0, R10, off) ]
  @ op

and cmp env depth j a b =
  binop env depth a b
    [ Alu (Mov, R2, Reg R0);
      Alu (Mov, R0, Imm 1l);
      Jmp (j, R2, Reg R1, 1);
      Alu (Mov, R0, Imm 0l) ]

let compile e = gen [] 0 e
