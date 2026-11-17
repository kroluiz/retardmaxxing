type token =
  | IDENT of string
  | INT of int64
  | LET
  | IN
  | IF
  | THEN
  | ELSE
  | PLUS
  | MINUS
  | MUL
  | DIV
  | EQ
  | EQEQ
  | NEQ
  | GT
  | LT
  | LPAR
  | RPAR
  | EOF

let is_digit c = match c with '0'..'9' -> true | _ -> false

let is_char_valid_ident c = match c with 'a'..'z' | 'A'..'Z' | '0'..'9' | '_' -> true | _ -> false

let keyword_or_ident word =
  match word with
  | "zet" -> LET
  | "zf" -> IF
  | "zhen" -> THEN
  | "elze" -> ELSE
  | "in" -> IN
  | _ -> IDENT word

let tokenize (s : string) : token list =
  let n = String.length s in

  let rec scan_digits k =
    if k < n && is_digit s.[k] then scan_digits (k + 1)
    else k
  in

  let rec scan_ident k =
    if k < n && is_char_valid_ident s.[k] then scan_ident (k + 1)
    else k
  in

  (*
    let x = 40 in
    if x > 10 then x + 2 else 0
  *)
  let rec go i acc =
    let j = i + 1 in
    if i >= n then List.rev (EOF :: acc)
    else
      match s.[i] with
      | ' ' | '\n' | '\t' -> go (i + 1) acc
      | '+' -> go (i + 1) (PLUS :: acc)
      | '-' -> go (i + 1) (MINUS :: acc)
      | '=' ->
          if j < n && s.[j] = '=' then go (i + 2) (EQEQ :: acc)
          else go (i + 1) (EQ :: acc)
      | '!' ->
          if j < n && s.[j] = '=' then go (i + 2) (NEQ :: acc)
          else failwith (Printf.sprintf "operator ! at %d doesnt exist" i)
      | '*' -> go (i + 1) (MUL :: acc)
      | '/' -> go (i + 1) (DIV :: acc)
      | '(' -> go (i + 1) (LPAR :: acc)
      | ')' -> go (i + 1) (RPAR :: acc)
      | '>' -> go (i + 1) (GT :: acc)
      | '<' -> go (i + 1) (LT :: acc)
      | '0'..'9' ->
          let stop = scan_digits i in
          go (stop) (INT (Int64.of_string (String.sub s i (stop - i))) :: acc)
      | 'a'..'z' | 'A'..'Z' ->
          let stop = scan_ident i in
          let z = keyword_or_ident (String.sub s i (stop - i)) in
          go (stop) (z :: acc)
      | c -> failwith (Printf.sprintf "unexpected '%c' at %d" c i)
  in
  go 0 []
