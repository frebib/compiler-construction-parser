open Types
open Print
open Printf

let rec map_bool fn e = fn (get_bool e)
and get_bool = function
  | Boolean b -> b
  | Const i   -> (i > 0)
  | _ -> failwith "Not a boolean type"
and map_int fn e  = fn (get_int e)
and map_int_inc e = Const (map_int (fun i -> i + 1) e)
and map_int_dec e = Const (map_int (fun i -> i - 1) e)
and get_int = function
  | Const i   -> i
  | _ -> failwith "Not an integer type"

and exp_compare a b = match a, b with
  | Const i, Const j     -> compare i j
  | Boolean i, Boolean j -> compare i j
  | _, _ -> compare a b (* This will probably fail but yolo *)
;;

let rec find_var ht = function
  | Identifier s -> Hashtbl.find ht s
  | e -> failwith ("Not a variable. Can't lookup: " ^ string_of_exp e)

and put_var ht e v = match e with
  | Identifier s -> Hashtbl.replace ht s v
  | e -> failwith ("Not a variable. Can't store: " ^ string_of_exp e)

and map_var ht fn = function
  (* Fetch, map and update the value. Return the Identifier *)
  | e -> find_var ht e |> fn |> put_var ht e; e

let rec eval_exp ht = function
  | Asg (e1, e2)    -> let rhs = eval_exp ht e2 in
                       let lhs = eval_exp ht e1 in
                       put_var ht lhs rhs; Empty

  | If (e, tr, fa)  -> if eval_exp ht e |> get_bool
                       then eval_exp ht tr
                       else eval_exp ht fa

  | While (e, body) -> while get_bool (eval_exp ht e) do
                       eval_exp ht body |> ignore done;
                       Empty

  | UnaryOp (op, e) -> (match op with
                        | PreInc  -> map_var ht map_int_inc e |> eval_exp ht
                        | PreDec  -> map_var ht map_int_dec e |> eval_exp ht
                        | PostInc -> eval_exp ht e |> map_var ht map_int_inc
                        | PostDec -> eval_exp ht e |> map_var ht map_int_dec
                        | Not     -> Boolean (eval_exp ht e |> map_bool (not))
                        | _ -> failwith ("Not a unary operator: " ^ string_of_op op))

  | BinaryOp (op, e1, e2) -> let v1 = eval_exp ht e1 in
                             let v2 = eval_exp ht e2 in
                             (match op with
                              | Plus    -> Const   ((get_int v1)  +  (get_int v2))
                              | Minus   -> Const   ((get_int v1)  -  (get_int v2))
                              | Times   -> Const   ((get_int v1)  *  (get_int v2))
                              | Divide  -> Const   ((get_int v1)  /  (get_int v2))
                              | Modulus -> Const   ((get_int v1)  mod (get_int v2))
                              | And     -> Boolean ((get_bool v1) && (get_bool v2))
                              | Or      -> Boolean ((get_bool v1) || (get_bool v2))
                              | Noteq   -> Boolean ((get_bool v1) != (get_bool v2))
                              | Equal   -> Boolean ((exp_compare v1 v2) == 0)
                              | Lth     -> Boolean ((exp_compare v1 v2) < 0)
                              | Gth     -> Boolean ((exp_compare v1 v2) > 0)
                              | Leq     -> Boolean ((exp_compare v1 v2) <= 0)
                              | Geq     -> Boolean ((exp_compare v1 v2) >= 0)
                              | _ -> failwith ("Not a binary operator" ^ string_of_op op))

  | Printint e   -> printf "%d\n" (get_int (eval_exp ht e)); Empty
  | Readint      -> Const (read_line () |> int_of_string)

  | Seq (hd, tl) -> eval_exp ht hd |> ignore; eval_exp ht tl
  | Deref e      -> eval_exp ht e |> find_var ht
  | e            -> e

let eval exp = eval_exp (Hashtbl.create 8) exp;