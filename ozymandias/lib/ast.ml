type expr =
  | Int of int64
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr
  | Div of expr * expr
  | Lt of expr * expr
  | Gt of expr * expr
  | Eq of expr * expr
  | Neq of expr * expr
  | If of expr * expr * expr
  | Let of string * expr * expr
  | Var of string
