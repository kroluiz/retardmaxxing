open Lexer
open Ast

let infix_bp tok =
  match tok with
  | EQEQ | NEQ | LT | GT -> Some (1, 2)
  | PLUS | MINUS -> Some (3, 4)
  | MUL | DIV -> Some (5, 6)
  | _ -> None

let binop tok a b =
  match tok with
  | PLUS -> Add (a, b)
  | MINUS -> Sub (a, b)
  | MUL -> Mul (a, b)
  | DIV -> Div (a, b)
  | EQEQ -> Eq (a, b)
  | NEQ -> Neq (a, b)
  | LT -> Lt (a, b)
  | GT -> Gt (a, b)
  | _ -> failwith "not an operator"

let expect tok tokens =
  match tokens with
  | t :: rest when t = tok -> rest
  | _ -> failwith "syntax error"

let rec parse_expr tokens min_bp =
  let (lhs, rest) = parse_prefix tokens in
  parse_infix lhs rest min_bp

and parse_infix lhs tokens min_bp =
  match tokens with
  | op :: rest ->
      (match infix_bp op with
       | Some (l_bp, r_bp) when l_bp >= min_bp ->
           let (rhs, rest) = parse_expr rest r_bp in
           parse_infix (binop op lhs rhs) rest min_bp
       | _ -> (lhs, tokens))
  | [] -> (lhs, tokens)

and parse_prefix tokens =
  match tokens with
  | INT n :: rest -> (Int n, rest)
  | IDENT name :: rest -> (Var name, rest)
  | LPAR :: rest ->
      let (e, rest) = parse_expr rest 0 in
      (e, expect RPAR rest)
  | LET :: IDENT name :: EQ :: rest ->
      let (value, rest) = parse_expr rest 0 in
      let (body, rest) = parse_expr (expect IN rest) 0 in
      (Let (name, value, body), rest)
  | IF :: rest ->
      let (cond, rest) = parse_expr rest 0 in
      let (a, rest) = parse_expr (expect THEN rest) 0 in
      let (b, rest) = parse_expr (expect ELSE rest) 0 in
      (If (cond, a, b), rest)
  | _ -> failwith "syntax error"

let parse tokens =
  match parse_expr tokens 0 with
  | (e, [EOF]) -> e
  | _ -> failwith "syntax error"
