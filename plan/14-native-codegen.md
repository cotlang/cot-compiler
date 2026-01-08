# Native Code Generation Plan

**Goal:** Make Cot 100% self-hosted like Go - the Cot compiler and runtime written entirely in Cot, compiling to native machine code.

## Vision

```
Current State:                    Goal State:
┌──────────────┐                 ┌──────────────┐
│  Cot Source  │                 │  Cot Source  │
└──────┬───────┘                 └──────┬───────┘
       │                                │
       ▼                                ▼
┌──────────────┐                 ┌──────────────┐
│ Zig Compiler │                 │ Cot Compiler │ ← written in Cot
└──────┬───────┘                 │ (self-hosted)│
       │                         └──────┬───────┘
       ▼                                │
┌──────────────┐                        ▼
│   Bytecode   │                 ┌──────────────┐
└──────┬───────┘                 │ Native Code  │ ← ARM64/x86_64
       │                         └──────────────┘
       ▼
┌──────────────┐
│  Zig/Rust VM │ ← eliminated
└──────────────┘
```

## Backend Strategy

We use a **tiered backend approach** like modern compilers:

| Backend | Purpose | Compile Speed | Code Quality | Complexity |
|---------|---------|---------------|--------------|------------|
| **gen_dev** | Development | 🚀 Instant | Basic | Low |
| **Cranelift** | Release | ⚡ Fast | Good | Medium |
| ~~LLVM~~ | ~~Maximum opt~~ | 🐢 Slow | Best | High |

**Decision:** Use **Cranelift** for production instead of LLVM because:
- Pure Rust integration (trivial to add to cot-rs)
- Fast compilation (designed for JIT, good for AOT)
- Good code quality (80-90% of LLVM)
- Small dependency footprint
- Used in production: Wasmtime, Rust (experimental), Firefox

## Target Platforms

| Priority | Target | Status |
|----------|--------|--------|
| 1 | aarch64-apple-darwin (Apple Silicon) | ✅ Started |
| 2 | x86_64-apple-darwin (Intel Mac) | Planned |
| 3 | x86_64-unknown-linux-gnu | Planned |

---

## Phase 1: gen_dev Backend (Development Builds)

**Purpose:** Fast compilation for development iteration. Direct machine code emission without optimization passes.

**Location:** `cot-rs/src/native_gen/`

```
cot-rs/src/native_gen/
├── mod.rs              # Backend trait, target selection
├── aarch64.rs          # ARM64 instruction emission
├── x86_64.rs           # (future) Intel instruction emission
└── object_builder.rs   # Mach-O/ELF generation
```

### Milestone 1.1: Hello Native World ✅ COMPLETE

**MVP:** Compile `fn main() { return 42 }` → native executable that exits with code 42.

- [x] AArch64Assembler with basic instructions (MOV, ADD, SUB, MUL, RET)
- [x] ObjectBuilder for Mach-O output
- [x] Link with system linker (`ld`)
- [x] Integration test: compile, run, verify exit code

### Milestone 1.2: Integer Arithmetic ✅ COMPLETE

**MVP:** Compile `fn main() { return (10 + 5) * 2 - 3 }` → correct result.

- [x] All arithmetic opcodes: ADD, SUB, MUL, DIV, MOD
- [x] Unary NEG
- [x] Immediate variants: ADDI, SUBI, MULI, INCR, DECR
- [x] Test: arithmetic expression evaluation

### Milestone 1.3: Comparisons & Logic ✅ COMPLETE

**MVP:** Compile `fn max(a, b) { if a > b { return a } else { return b } }`.

- [x] Comparison opcodes: CMP_EQ, CMP_NE, CMP_LT, CMP_LE, CMP_GT, CMP_GE
- [x] Logical opcodes: LOG_AND, LOG_OR, LOG_NOT
- [x] Conditional set (CSET for boolean results)
- [x] Test: comparison functions

### Milestone 1.4: Control Flow ✅ COMPLETE

**MVP:** Compile loops and conditionals: `while i < 10 { sum = sum + i; i = i + 1 }`.

- [x] Unconditional jump: JMP
- [x] Conditional jumps: JZ, JNZ (using CBZ/CBNZ)
- [x] Branch instructions with label resolution (jump relocation)
- [x] Test: loop computing sum 1+2+3+4+5

### Milestone 1.5: Functions & Locals ✅ COMPLETE

**MVP:** Compile multi-function programs with local variables.

- [x] CALL instruction with proper ABI (BL to routine offsets)
- [x] Stack frame setup/teardown (push_frame/pop_frame)
- [x] Local variable allocation (LOAD_LOCAL, STORE_LOCAL via SP-relative)
- [x] Parameter passing (r0-r7 → x0-x7)
- [x] Test: function call add5(10) = 15

### Milestone 1.6: Strings & I/O ✅ COMPLETE

**MVP:** Compile `fn main() { println("Hello, World!") }` → prints output.

- [x] String constants in data section (embedded in code section for MVP)
- [x] LOAD_CONST for string references (ADR instruction + patching)
- [x] System call wrapper for write (macOS ARM64 syscall)
- [x] println native function (Print/Println opcodes)
- [x] Test: hello world program

### Milestone 1.7: Heap & Records ✅ COMPLETE

**MVP:** Compile programs that allocate and use structs.

- [x] malloc/free via libc FFI (external call relocations)
- [x] NEW_RECORD opcode (calls malloc)
- [x] LOAD_FIELD, STORE_FIELD (pointer + offset addressing)
- [x] Test: record create/store/load/add returns 42

**Phase 1 Complete When:** Can compile a non-trivial Cot program (e.g., a small utility) to native executable that runs correctly.

---

## Phase 2: Cranelift Backend (Production Builds)

**Purpose:** Optimized native code for release builds. Better performance than gen_dev with reasonable compile times.

**Location:** `cot-rs/src/cranelift_gen/`

### Milestone 2.1: Cranelift Integration

**MVP:** Same test suite as gen_dev passes with Cranelift backend.

- [ ] Add `cranelift-codegen` dependency
- [ ] Implement `CraneliftBackend` trait
- [ ] IR translation: Cot bytecode → Cranelift IR
- [ ] Test: all Phase 1 tests pass

### Milestone 2.2: Optimization Passes

**MVP:** Cranelift output runs measurably faster than gen_dev on benchmarks.

- [ ] Enable Cranelift optimization levels
- [ ] Benchmark comparison: gen_dev vs Cranelift
- [ ] Document performance characteristics

### Milestone 2.3: Full Opcode Coverage

**MVP:** Every Cot opcode compiles correctly through Cranelift.

- [ ] Map all ~150 opcodes to Cranelift IR
- [ ] Handle edge cases (overflow, null checks, etc.)
- [ ] Comprehensive test coverage

**Phase 2 Complete When:** Can compile any valid Cot program to optimized native code.

---

## Phase 3: FFI Bridge to Cot

**Purpose:** Allow Cot code to invoke the native compiler, enabling self-hosting.

### Milestone 3.1: C Library Wrapper ✅ COMPLETE

**MVP:** Native compiler exposed as C-callable library.

```c
// libcot_codegen.h
typedef struct CotModule CotModule;
typedef struct CotNativeCode CotNativeCode;

CotModule* cot_module_load(const uint8_t* data, size_t len);
CotNativeCode* cot_compile_native(CotModule* module, int optimize);
int cot_write_object(CotNativeCode* code, const char* path);
int cot_link(const char** objects, size_t count, const char* output);
void cot_free_module(CotModule* module);
void cot_free_native(CotNativeCode* code);
```

- [x] Create `cot-rs` cdylib target (Cargo.toml crate-type)
- [x] Implement C API functions (src/ffi.rs)
- [x] C header file (include/cot_codegen.h)
- [ ] Test from C program

### Milestone 3.2: Cot FFI Bindings

**MVP:** Cot code can call native compiler functions.

```cot
// native_compiler.cot
extern fn cot_module_load(data: *u8, len: i64) *Module
extern fn cot_compile_native(module: *Module, optimize: i32) *NativeCode
extern fn cot_write_object(code: *NativeCode, path: *u8) i32
extern fn cot_link(objects: **u8, count: i64, output: *u8) i32

fn compileToNative(bytecode: []u8, output: string, optimize: bool) bool {
    const module = cot_module_load(bytecode.ptr, bytecode.len)
    const code = cot_compile_native(module, if optimize { 1 } else { 0 })
    cot_write_object(code, output.ptr)
    return true
}
```

- [ ] FFI declarations in cot-compiler
- [ ] Integration with existing compiler pipeline
- [ ] Test: compile simple program from Cot

**Phase 3 Complete When:** The Cot compiler can emit native executables (via FFI to Rust backend).

---

## Phase 4: Self-Hosted Compiler

**Purpose:** The Cot compiler compiles itself to native code.

### Milestone 4.1: Bootstrap Stage 1

**MVP:** Rust VM compiles cot-compiler to native executable.

```bash
# Using Rust VM to compile cot-compiler
cot-rs compile cot-compiler/src/*.cot --native -o cot-native
./cot-native --version  # Works!
```

- [ ] cot-compiler compiles successfully with native backend
- [ ] Native cot-compiler runs basic commands
- [ ] Test: native compiler produces valid bytecode

### Milestone 4.2: Bootstrap Stage 2

**MVP:** Native cot-compiler compiles itself.

```bash
# Native compiler compiles itself
./cot-native compile cot-compiler/src/*.cot --native -o cot-native-2
```

- [ ] Self-compilation succeeds
- [ ] Output is a working compiler
- [ ] No crashes or errors

### Milestone 4.3: Bootstrap Verification

**MVP:** `cot-native-2` produces identical output to `cot-native`.

```bash
# Verify bootstrap
./cot-native compile test.cot -o test1.cbo
./cot-native-2 compile test.cot -o test2.cbo
diff test1.cbo test2.cbo  # Should be identical
```

- [ ] Byte-for-byte identical bytecode output
- [ ] Identical native code output
- [ ] Documented bootstrap process

**Phase 4 Complete When:** Cot compiler is fully self-hosting - compiles itself to native.

---

## Phase 5: Native Runtime

**Purpose:** Eliminate dependency on Zig/Rust VM by implementing runtime in Cot + minimal native code.

### Milestone 5.1: Memory Management

**MVP:** Programs manage memory without VM.

- [ ] malloc/free wrappers via libc
- [ ] Reference counting or simple GC in Cot
- [ ] ARC operations compile to native

### Milestone 5.2: String Runtime

**MVP:** String operations work natively.

- [ ] String allocation and concatenation
- [ ] String comparison
- [ ] String slicing

### Milestone 5.3: I/O Runtime

**MVP:** File and console I/O without VM.

- [ ] System calls for read/write
- [ ] File open/close/seek
- [ ] println, readln implementations

### Milestone 5.4: Collections Runtime

**MVP:** List and Map work natively.

- [ ] List allocation and operations
- [ ] Map (hash table) implementation
- [ ] Iteration support

**Phase 5 Complete When:** Cot programs run as native executables without any VM.

---

## Phase 6: Full Self-Hosting (Go-Level)

**Purpose:** Cot builds itself from source with minimal external dependencies.

### Milestone 6.1: Minimal Dependencies

**MVP:** Only requires: OS, system linker, C library.

- [ ] Remove Rust runtime dependency
- [ ] Remove Zig runtime dependency
- [ ] Document exact dependencies

### Milestone 6.2: Bootstrap from Source

**MVP:** Can build Cot on a fresh machine with only a seed compiler.

```bash
# On fresh machine with only seed binary
./cot-seed compile cot-compiler/src/*.cot --native -o cot
./cot compile cot-compiler/src/*.cot --native -o cot-final
# cot-final is the production compiler
```

- [ ] Seed compiler binary (checked into repo or downloadable)
- [ ] Single-command build process
- [ ] Works on macOS and Linux

### Milestone 6.3: Cross-Compilation

**MVP:** Compile for different targets from any host.

- [ ] aarch64-apple-darwin from x86_64
- [ ] x86_64-linux from macOS
- [ ] Target selection via flag

**Phase 6 Complete When:** Cot is fully self-hosted like Go - builds itself from source with no external language dependencies.

---

## Technical Reference

### ARM64 Calling Convention (AAPCS64)

| Register | Purpose | Saved By |
|----------|---------|----------|
| x0-x7 | Arguments/Return | Caller |
| x8 | Indirect result | Caller |
| x9-x15 | Temporaries | Caller |
| x16-x17 | Scratch | - |
| x18 | Platform (reserved) | - |
| x19-x28 | Callee-saved | Callee |
| x29 | Frame pointer | Callee |
| x30 | Link register | Callee |
| SP | Stack pointer | - |

### Cot → ARM64 Register Mapping

| Cot | ARM64 | Notes |
|-----|-------|-------|
| r0-r7 | x0-x7 | Args/return, caller-saved |
| r8-r13 | x19-x24 | Callee-saved |
| r14 | x29 | Frame pointer |
| r15 | x0 | Return value alias |

### Dependencies by Phase

| Phase | External Dependencies |
|-------|----------------------|
| 1-2 | Rust, `object` crate, `cranelift` crate, system linker |
| 3-4 | Rust (for FFI library), system linker |
| 5 | System linker, libc |
| 6 | System linker only (libc optional with raw syscalls) |

---

## File References

- `cot-rs/src/native_gen/` - gen_dev backend
- `cot-rs/src/cranelift_gen/` - (future) Cranelift backend
- `cot-compiler/src/` - Self-hosted compiler source
- `~/learning/roc/crates/compiler/gen_dev/` - Roc reference implementation

---

## Progress Tracking

| Phase | Status | MVP Target |
|-------|--------|------------|
| 1.1 Hello World | ✅ Complete | return 42 works |
| 1.2 Arithmetic | ✅ Complete | expressions work |
| 1.3 Comparisons | ✅ Complete | comparisons work |
| 1.4 Control Flow | ✅ Complete | loops work |
| 1.5 Functions | ✅ Complete | multi-function works |
| 1.6 Strings/IO | ✅ Complete | println works |
| 1.7 Heap/Records | ✅ Complete | structs work |
| 2.1 Cranelift Setup | ✅ Complete | basic IR translation |
| 2.2 Cranelift Ops | 🔄 In Progress | arithmetic/logic/flow |
| 2.3 Full Cranelift | 🔲 Not started | all ~150 opcodes |
| 3.1 C Library | ✅ Complete | libcot_rs.dylib ready |
| 3.2 Cot FFI | 🔲 Not started | Cot calls native compiler |
| 4.x Self-Host | 🔲 Not started | bootstrap works |
| 5.x Runtime | 🔲 Not started | no VM needed |
| 6.x Full Self-Host | 🔲 Not started | Go-level independence |
