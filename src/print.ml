open Types
open List
open Printf

let concat = String.concat;;

(* string_of_x functions mostly for debugging *)
let rec string_of_op = function
  | Plus -> "Plus"
  | Minus -> "Minus"
  | Times -> "Times"
  | Divide -> "Divide"
  | Modulus -> "Modulus"
  | Lth -> "Lth"
  | Gth -> "Gth"
  | Leq -> "Leq"
  | Geq -> "Geq"
  | PreInc -> "PreInc"
  | PreDec -> "PreDec"
  | PostInc -> "PostInc"
  | PostDec -> "PostDec"
  | Equal -> "Equal"
  | Noteq -> "Noteq"
  | And -> "And"
  | Or -> "Or"
  | Not -> "Not"

and string_of_unop_exp op e = 
  string_of_op op ^ ", " ^ string_of_exp e

and string_of_exp = function
  | Empty                 -> "Empty"
  | Function (a, e)       -> "Function " ^ wrap (wrap_sq (map esc a |> concat "; ") ^ ", " ^ string_of_exp e)
  | BoundFunction (a, e, _) -> "Bound" ^ string_of_exp (Function (a, e))
  | Ref s                 -> "Ref " ^ esc s
  | Seq l                 -> "Seq " ^ wrap_sq (map string_of_exp l |> concat "; ")
  | While (e, f)          -> "While " ^ wrap (string_of_exp e ^ ", " ^ string_of_exp f)
  | If (e, a, b)          -> "If " ^ wrap ([e;a;b] |> map string_of_exp |> concat ", ")
  | Asg (x, v)            -> "Asg " ^ wrap (string_of_exp x ^ ", " ^ string_of_exp v)
  | Deref x               -> "Deref " ^ wrap (string_of_exp x)
  | UnaryOp (op, e)       -> "UnaryOp " ^ wrap (string_of_unop_exp op e)
  | BinaryOp (op, e1, e2) -> "BinaryOp "  ^ wrap (string_of_op op ^ ", " ^ string_of_exp e1 ^ ", " ^ string_of_exp e2)
  | Application (f, l)    -> "Application " ^ wrap (string_of_exp f ^ ", " ^ wrap_sq (map string_of_exp l |> concat "; "))
  | Const n               -> "Const " ^ if n < 0 then wrap (string_of_int n) else string_of_int n
  | Boolean b             -> "Boolean " ^ string_of_bool b
  | Readint               -> "Readint"
  | Printint e            -> "Printint" ^ wrap (string_of_exp e)
  | Identifier s          -> "Identifier " ^ esc s
  | Let (x, v, e)         -> "Let " ^ wrap ([esc x; string_of_exp v; string_of_exp e] |> concat ", ")
  | New (x, v, e)         -> "New " ^ wrap ([esc x; string_of_exp v; string_of_exp e] |> concat ", ")

and string_of_prog p = List.map string_of_exp p
                      |> String.concat ";\n"
                      |> sprintf "[\n%s\n]"
;;

(* Indents lines by n spaces *)
let indent count =
  let spaces = Bytes.to_string (Bytes.make count ' ') in
  Str.global_replace (Str.regexp "^") spaces
;;

