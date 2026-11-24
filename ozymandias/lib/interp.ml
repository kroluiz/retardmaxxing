open Ast

let rec eval env e =
  match e with
  | Int n -> n
  | Add (a, b) -> eval_arith env Int64.add a b
  | Sub (a, b) -> eval_arith env Int64.sub a b
  | Mul (a, b) -> eval_arith env Int64.mul a b
  | Div (a, b) ->
      let x = eval env a in
      let y = eval env b in
      if Int64.equal y 0L then 0L
      else Int64.div x y
  | Lt (a, b) -> eval_cmp env (<) a b
  | Gt (a, b) -> eval_cmp env (>) a b
  | Eq (a, b) -> eval_cmp env (=) a b
  | Neq (a, b) -> eval_cmp env (<>) a b
  | If (a, b, c) -> eval_if env a b c
  | Let (name, value, body) -> eval_let env name value body
  | Var name -> List.assoc name env

and eval_cmp env op a b =
  let x = eval env a in
  let y = eval env b in
  if op x y then 1L else 0L

and eval_arith env op a b =
  let x = eval env a in
  let y = eval env b in
  op x y

and eval_if env cond b c =
  let x = eval env cond in
  if x <> 0L then eval env b
  else eval env c

and eval_let env name value body =
  let v = eval env value in
  eval ((name, v) :: env) body

let run source = eval [] (Parser.parse (Lexer.tokenize source))
