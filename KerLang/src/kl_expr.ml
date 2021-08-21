open Kl_parsing

type 'a statement =
  | TAKES of 'a
  | LET of string * 'a
  | RETURNS of 'a
  | USES of 'a
  | NONE

type 'a operation =
  | IF of 'a * 'a * 'a
  | SUM of 'a * 'a
  | DIFF of 'a * 'a
  | PROD of 'a * 'a
  | DIV of 'a * 'a
  | APPLY of string * 'a list
  (* IDEA : apply to a hole (SOMETHING) !!! *)
  | SELF of 'a list

type value =
  | ARG of int
  | CONST of int
  | VAR of string
  | SOMETHING

type expr =
  | Leaf of value
  | Node of value operation

type result =
  | RETURN of expr
  | YOLO of expr list

type comment_function = {
  n_args : int;
  declarations : (string * expr) list;
  result : result;
}


let split_lines (comment : tok list) : tok list list =
  let rec split (res : tok list list) (curr_expr : tok list) = function
  | Sep::q -> split ((List.rev curr_expr)::res) [] q
  | token::q -> split res (token::curr_expr) q
  | [] -> List.rev res
in split [] [] comment

let string_of_tok = function
  | Int(_, n) -> string_of_int n
  | Word(_, w) -> w
  | Sep -> ""

let rec string_of_comment = function
  | [] -> ""
  | [t] -> string_of_tok t
  | t::q -> (string_of_tok t) ^ (string_of_comment q)

let look_for (kw : string) (comment : tok list) : tok list * tok list =
  let rec search (prev : tok list) = function
  | [] -> failwith ("keyword" ^ kw ^ "not found")
  | t::q -> if string_of_tok t = kw then (List.rev prev, q)
  else search (t::prev) q
in search [] comment

let split_kw (kw : string) (comment : tok list) : tok list list =
  let rec split (res : tok list list) (curr_expr : tok list) = function
  | [] -> List.rev ((List.rev curr_expr)::res)
  | t::q -> if string_of_tok t = kw then split ((List.rev curr_expr)::res) [] q
  else split res (t::curr_expr) q
in split [] [] comment

let parse_value (comment : tok list) : value =
  match comment with
  | [] -> SOMETHING
  | t::q -> (
    match t with
    | Int(_, n) -> CONST n
    | _ -> match string_of_tok t with
      | "argument" -> (
        match q with
        | Int(_, n)::_ -> ARG n
        | _ -> failwith "expected argument number"
      )
      | "something" -> SOMETHING
      | s -> VAR s
  )

let parse_operation (comment : tok list) =
  let f = parse_value in
  let rec search (prev : tok list) = function
  | [] -> failwith "no operation"
  | t::q -> (
    match string_of_tok t with
    | "if" -> let a, b = look_for "and" q in let b, _ = look_for "otherwise" b in IF (f (List.rev prev), f a, f b)
    | "addition" -> let _, b = look_for "of" q in let a, b = look_for "and" b in SUM (f a, f b)
    | "difference" -> let _, b = look_for "of" q in let a, b = look_for "and" b in DIFF (f a, f b)
    | "product" -> let _, b = look_for "of" q in let a, b = look_for "and" b in PROD (f a, f b)
    | "division" -> let _, b = look_for "of" q in let a, b = look_for "and" b in DIV (f a, f b)
    | "application" -> let _, b = look_for "of" q in let a, b = look_for "on" b in
      let s = string_of_comment a and l = split_kw "and" b in
      if s = "self" then SELF(List.map f l) else APPLY (s, List.map f l)
    | _ -> search (t::prev) q
  )
in search [] comment

let rec parse_statement (comment : tok list) =
  let f x = try Node (parse_operation x) with _ -> Leaf (parse_value x) in
  match comment with
  | [] -> NONE
  | t::q -> (
    match string_of_tok t with
    | "takes" -> TAKES (f q)
    | "let" -> let a, b = look_for "be" q in LET (string_of_comment a, f b)
    | "returns" -> RETURNS (f q)
    | "uses" -> USES (f q)
    | _ -> parse_statement q
  )
