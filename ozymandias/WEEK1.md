# Week 1 — from zero OCaml to "my language runs in the kernel"

## Goal for day 7

```
let x = 40 in
if x > 10 then x + 2 else 0
```

That program goes through your parser and codegen, becomes raw eBPF bytes, is loaded with your
own `bpf()` syscall binding, and is run by the kernel through `BPF_PROG_TEST_RUN`. The kernel
returns `42`. A property test then checks that the kernel and your interpreter agree on
thousands of random programs.

No kprobes or maps this week. `BPF_PROG_TEST_RUN` runs a program on fake input and hands back
its return value, so you get a tight feedback loop without attaching anything.

## Language v0

- 64-bit integers only
- `+ - * /`, `< > == !=`
- `let x = e in e`
- `if e then e else e`
- The program's value is the return value (`r0`)

Keep it small. Every feature gets added later, deliberately.

## Layout

```
retardmaxxing/
  dune-project
  bin/main.ml           # CLI: compile / run / dump
  lib/
    ast.ml              # types only
    lexer.ml
    parser.ml           # hand-written, Pratt for expressions
    interp.ml           # reference semantics, the oracle
    ebpf.ml             # instruction type + 8-byte encoder
    codegen.ml          # Ast -> Ebpf.insn list
    loader.ml           # OCaml side of the syscall
    bpf_stubs.c         # C side: bpf(BPF_PROG_LOAD / BPF_PROG_TEST_RUN)
  test/
  LOG.md                # decisions + numbers, a few lines per day
```

## Days

### Day 1 — Toolchain + OCaml basics
- Install `opam`, then `opam init`, then an OCaml 5.x switch, then
  `opam install dune ocaml-lsp-server utop ppx_expect qcheck`.
- Read only what `eval` needs: Real World OCaml ch. 1 (skim), ch. 6 Variants (properly),
  ch. 3 pattern-matching part. Records, modules, error handling: read them when a later day
  needs them. RWO uses Jane Street's `Base`; ignore it and stick to the stdlib.
- Exercise: define `type expr = Int of int64 | Add of expr * expr | ...` and write
  `eval : expr -> int64` in utop. That's your interpreter in miniature.
- Ask AI: "explain this type error" is fine. "Write this for me" isn't.

### Day 2 — Lexer + parser
- Write a token type and a lexer over a `string` with an index.
- Write a Pratt parser for binary ops (precedence climbing). Read about Pratt parsing first, then
  close the article and write it yourself.
- Expect tests (`ppx_expect`): parse a source string, print the AST, snapshot it.
- Decision for LOG.md: how will you report errors (exceptions vs `result`)?

### Day 3 — Interpreter as the source of truth
- `interp.ml` with `let` environments.
- **Design decision:** what is `x / 0`? eBPF defines it as `0` (no trap). Either the language
  says the same, or codegen inserts a check. Pick one, write down why.
- The same applies to overflow: eBPF wraps at 64 bits, and so does OCaml's `Int64`. Good.

### Day 4 — eBPF instruction encoding
- Read RFC 9669 (the eBPF ISA), sections on encoding, ALU, JMP. Also skim
  `man 2 bpf`.
- In `ebpf.ml`, write a variant type for the instructions you need (`mov`, `alu64` ops,
  `jcond`, `ja`, `ldx/stx` on r10, `exit`) plus `encode : insn -> bytes` (8 bytes,
  little-endian, opcode/regs/off/imm).
- Expect-test the bytes by hand against the RFC tables. Check every byte here: this
  is the "care about each byte" day.

### Day 5 — Talking to the kernel
- `bpf_stubs.c`: a thin wrapper over `syscall(__NR_bpf, ...)` for `BPF_PROG_LOAD` with
  `BPF_PROG_TYPE_SOCKET_FILTER`, license "GPL", and a 64KB verifier log buffer. It returns the fd
  or raises with the log.
- Wire it through dune's `foreign_stubs`. Learn `CAMLparam` / `CAMLreturn` / `caml_alloc`
  properly. The OCaml FFI is unforgiving.
- Load a hand-assembled `r0 = 42; exit` program.
- Your kernel has `unprivileged_bpf_disabled=2`, so run with `sudo` or
  `sudo setcap cap_bpf,cap_perfmon+ep` on the binary.
- Verify it with `sudo bpftool prog list` and `sudo bpftool prog dump xlated id <N>`.

### Day 6 — Codegen
- Add `BPF_PROG_TEST_RUN` to the stubs (pass a dummy 64-byte packet, read back `retval`).
  Socket filter retval is 32-bit, so either use XDP/`BPF_PROG_TYPE_SCHED_CLS` or accept the
  truncation for now. Note it in LOG.md.
- Naive codegen: every subexpression result goes to a stack slot off `r10` (fp), and binops load
  into r1/r2, compute, then store. It's slow and ugly but correct. The 512-byte stack limit will
  show up quickly. Good.
- `let` → a stack slot, `if` → conditional jump with patched offsets (forward refs:
  first time you'll want labels + a second pass).

### Day 7 — Differential testing + first numbers
- QCheck generator for random well-formed programs, with the property
  `Interp.eval p = Kernel.run (Codegen.compile p)`.
- Fix whatever it finds. It will find things (sign of comparisons, jump offsets, division).
- Record instruction count per program in LOG.md. That's the baseline every future
  optimization (register allocation, constant folding) gets measured against.

## Where to go after week 1
Register allocation (r6–r9 callee-saved, r1–r5 clobbered by calls), maps, helper calls,
a real attach point (kprobe via `perf_event_open`), then making the verifier accept loops.

## Resources
- Real World OCaml: https://dev.realworldocaml.org
- OCaml Programming (Cornell CS3110): https://cs3110.github.io/textbook
- RFC 9669, BPF Instruction Set Architecture
- Kernel: `Documentation/bpf/` (verifier.rst especially, from day 6 on)
- Crafting Interpreters (concepts only; it's not OCaml)
