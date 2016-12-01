open Types
open Print
open Printf
open AsmAtt

let mklbl = sprintf ".LBL%d"
let mkfun = sprintf ".FUN%d"

let fmt_instr  i a   = sprintf "%s\t%s"     i (string_of_location a)
let fmt_instr2 i a b = sprintf "%s\t%s, %s" i (string_of_location a) (string_of_location b)

let templ_printInt = 
".LC0:
	.string	\"%d\\n\"
	.text
	.globl	printInt
	.type	printInt, @function
printInt:
	subq	$8, %rsp
	movl	%edi, %esi
	xorl	%eax, %eax
	movl	$.LC0, %edi
	call	printf
	xorl	%eax, %eax
	addq	$8, %rsp
	ret
	.size	printInt, .-printInt\n"


(* Use classes for a stateful compilation
   - it makes more sense imo *)
class x86assembler = object(this)

  val symtbl = Hashtbl.create 1024

  val mutable sp = 0
  method incsp i = sp <- sp + i
  method decsp i = sp <- sp - i

  val mutable lblid = 0
  val mutable funid = 0
  method lblid = lblid <- lblid + 1; lblid
  method funid = funid <- funid + 1; funid

  val code = Buffer.create 1048576 (* 1024 ^ 2 *)
  val mutable funs = [] (* List of compiled functions *)
	val mutable registers = []

  method label  s     = Buffer.add_string code (s ^ ":\n")
  method labeln s i   = Buffer.add_string code (s ^ mklbl i ^ ":\n")
  method commnt s     = Buffer.add_string code ("\t// " ^ s ^ "\n")
  method instr s      = Buffer.add_string code ("\t" ^ s ^ "\n")
  method instr1 i a   = fmt_instr i a    |> this#instr  
  method instr2 i a b = fmt_instr2 i a b |> this#instr  

	(* Finds and reserves the next unused 64bit register *)
	method next_reg _ =
		let unused =
			Hashtbl.fold (fun k v ac -> match v with
				| Register v -> if List.mem v ac then ac else v :: ac
				| _ -> ac) symtbl registers
			|> fun l -> List.filter (fun x -> not (List.mem x l)) all_reg64
		in
		if List.length unused < 1 then
      (* Returns a stack address if no registers available *)
			(this#incsp 8; BasePtrOffs sp)
		else
			let reg = List.hd unused in
			registers <- (reg :: registers);
			DRegister reg

	(* Frees a reserved register *)
	method free_reg = function
		| Register r -> registers <- (List.filter (fun x -> r != x) registers)
		| _ -> ()

  method compile exp =
    (* Add printInt function *)
    funs <- templ_printInt :: funs;
    (* Add template code, compile program inside *)
    this#instr  ".globl	main";
    this#instr  ".type	main, @function";
    this#label  "main";
    this#instr1 "pushq" (DRegister RBP);
    this#instr2 "movq"  (DRegister RSP) (DRegister RBP);
    this#instr2 "xorq"  (DRegister RDI)	(DRegister RDI);
    this#commnt "End template code";
    let ret = this#genasm (Register RDI) exp in
    this#commnt "End of program code";
    this#commnt "Print and exit";
    this#instr  "call	printInt";
    this#instr  "xorl	%eax, %eax";
    this#instr  "leave";
    this#instr  "ret";
    this#instr  ".size	main, .-main\n";
    ret

  method private genasm = function
    | Register r ->
      let dest = DRegister r in
      (function
        | Const 0 -> this#instr2 "xorq" dest dest; dest
        | Const i -> this#instr2 "movq" (ConstInt i) dest; dest
        | e -> this#commnt (string_of_exp e); dest)

    | EmptyRegister -> (function
      | Const 0  -> let reg = this#next_reg () in
										this#instr2 "xorq" reg reg;	reg
      | Const i  -> let reg = this#next_reg () in
										this#instr2 "movq" (ConstInt i) reg; reg
      | e -> this#commnt (string_of_exp e); Void)

    | Stack -> (function
      | Const i -> Void
      | e -> this#commnt (string_of_exp e); Void)

    | Discard -> (function
      | Const i -> Void
      | e -> this#commnt (string_of_exp e); Void)

  method output_code o =
    List.iter (printf "%s\n") funs;
    Buffer.output_buffer o code;
 
end

let assemble e = 
  let assembler = new x86assembler in
  assembler#compile e |> ignore;
  assembler#output_code

