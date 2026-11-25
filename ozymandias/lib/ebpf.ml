type reg = R0 | R1 | R2 | R3 | R4 | R5 | R6 | R7 | R8 | R9 | R10

type src = Reg of reg | Imm of int32

type alu_op = Add | Sub | Mul | Sdiv | Rsh | Mov

type jmp_op = Jeq | Jne | Jsgt | Jslt

type insn =
  | Alu of alu_op * reg * src
  | Lddw of reg * int64
  | Ldx of reg * reg * int
  | Stx of reg * int * reg
  | Jmp of jmp_op * reg * src * int
  | Ja of int
  | Exit

let reg_num r =
  match r with
  | R0 -> 0 | R1 -> 1 | R2 -> 2 | R3 -> 3 | R4 -> 4 | R5 -> 5
  | R6 -> 6 | R7 -> 7 | R8 -> 8 | R9 -> 9 | R10 -> 10

let slot opcode dst src off imm =
  if off < -32768 || off > 32767 then invalid_arg "offset out of range";
  let b = Bytes.create 8 in
  Bytes.set_uint8 b 0 opcode;
  Bytes.set_uint8 b 1 ((src lsl 4) lor dst);
  Bytes.set_int16_le b 2 off;
  Bytes.set_int32_le b 4 imm;
  b

let src_parts s =
  match s with
  | Reg r -> (0x08, reg_num r, 0l)
  | Imm i -> (0x00, 0, i)

let alu_code op =
  match op with
  | Add -> 0x00
  | Sub -> 0x10
  | Mul -> 0x20
  | Sdiv -> 0x30
  | Rsh -> 0x70
  | Mov -> 0xb0

let jmp_code op =
  match op with
  | Jeq -> 0x10
  | Jne -> 0x50
  | Jsgt -> 0x60
  | Jslt -> 0xc0

let encode insn =
  match insn with
  | Alu (op, dst, s) ->
      let (x, src, imm) = src_parts s in
      let off = if op = Sdiv then 1 else 0 in
      slot (0x07 lor alu_code op lor x) (reg_num dst) src off imm
  | Lddw (dst, n) ->
      let lo = Int64.to_int32 n in
      let hi = Int64.to_int32 (Int64.shift_right_logical n 32) in
      Bytes.cat (slot 0x18 (reg_num dst) 0 0 lo) (slot 0x00 0 0 0 hi)
  | Ldx (dst, src, off) -> slot 0x79 (reg_num dst) (reg_num src) off 0l
  | Stx (dst, off, src) -> slot 0x7b (reg_num dst) (reg_num src) off 0l
  | Jmp (op, dst, s, off) ->
      let (x, src, imm) = src_parts s in
      slot (0x05 lor jmp_code op lor x) (reg_num dst) src off imm
  | Ja off -> slot 0x05 0 0 off 0l
  | Exit -> slot 0x95 0 0 0 0l

let assemble insns = Bytes.concat Bytes.empty (List.map encode insns)
