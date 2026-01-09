# cot-compiler Launch Readiness Plan

**Created:** 2026-01-09
**Updated:** 2026-01-09
**Purpose:** Refined gap analysis and actionable roadmap for self-hosting launch.

---

## Executive Summary

cot-compiler is **~85% ready** for self-hosting. The core pipeline (lexer, parser, type checker, IR lowering, bytecode emission) is code-complete and compiles successfully.

**Current State:**
- 10 modules, 10,802 lines, all compile to valid bytecode
- 12/12 bootstrap tests pass
- P0-P2 language features marked complete
- **150 opcode constants** defined in emit.cot (up from ~50)
- **171 emit functions** implemented

**Remaining Blocking Issues:**
1. ~~Missing 40+ opcodes in emit.cot~~ **RESOLVED** - Now has 150 opcodes
2. Import system not implemented (can only compile single files)
3. Native codegen incomplete (~30%)

---

## Gap Analysis: emit.cot vs opcodes.zig

### Opcodes Present in cot-compiler (50)

| Category | Opcodes |
|----------|---------|
| Core | NOP, HALT |
| Memory | MOV, MOVI, MOVI16, MOVI32, LOAD_CONST, LOAD_NULL, LOAD_TRUE, LOAD_FALSE |
| Locals/Globals | LOAD_LOCAL, STORE_LOCAL, LOAD_LOCAL16, STORE_LOCAL16, LOAD_GLOBAL, STORE_GLOBAL |
| Arithmetic | ADD, SUB, MUL, DIV, MOD, NEG |
| Comparison | CMP_EQ, CMP_NE, CMP_LT, CMP_LE, CMP_GT, CMP_GE |
| Logic | LOG_AND, LOG_OR, LOG_NOT, BIT_AND, BIT_OR, BIT_XOR, BIT_NOT, SHL, SHR |
| Control | JMP, JZ, JNZ |
| Calls | CALL, CALL_NATIVE, RET, RET_VAL |
| Records | NEW_RECORD, LOAD_FIELD, STORE_FIELD |
| Strings | STR_CONCAT, STR_LEN |
| Lists | LIST_NEW, LIST_PUSH, LIST_POP, LIST_GET, LIST_SET, LIST_LEN |
| Maps | MAP_NEW, MAP_SET, MAP_GET, MAP_DELETE, MAP_HAS, MAP_LEN |
| I/O | PRINT, PRINTLN |
| Error | SET_ERROR_HANDLER, CLEAR_ERROR_HANDLER, THROW |
| Debug | DEBUG_LINE |

### Critical Missing Opcodes (40+)

#### P0: Required for Self-Hosting

| Category | Missing Opcodes | Why Critical |
|----------|-----------------|--------------|
| **Stack Pointers** | `get_local_ptr` (0x7A), `load_indirect` (0x7B), `store_indirect` (0x7C), `ptr_offset` (0x59) | Struct-by-pointer passing (used throughout cot-compiler) |
| **ARC** | `arc_retain` (0xF5), `arc_release` (0xF6), `arc_move` (0xF7) | Memory management for heap objects |
| **Variants** | `variant_construct` (0x8A), `variant_get_tag` (0x8B), `variant_get_payload` (0x8C) | Sum type pattern matching (TokenType, StmtKind, etc.) |
| **Closures** | `make_closure` (0xF8), `call_closure` (0xF9) | Lambda expressions in parser |

#### P1: Required for Full Language Support

| Category | Missing Opcodes | Use Case |
|----------|-----------------|----------|
| **Struct Collections** | `list_push_struct` (0xB5), `list_get_struct` (0xB6), `list_set_struct` (0xB8) | `List<Token>`, `List<Stmt>` in compiler |
| **String Ops** | `str_index` (0x92), `str_slice` (0x93), `str_trim` (0x95), `str_find` (0x98) | String manipulation in lexer |
| **Comparison Jumps** | `jeq` (0x64), `jne` (0x65), `jlt` (0x66), `jge` (0x67) | Optimized switch/loop code |
| **Type Ops** | `is_null` (0x57), `is_type` (0x5C), `select` (0x58) | Optional types, type checking |
| **Increments** | `incr` (0x39), `decr` (0x3A) | Loop counters |
| **Call Variants** | `call_indirect` (0x73), `push_arg` (0x77), `pop_arg` (0x79) | Overflow args, function pointers |

#### P2: Nice to Have

| Category | Missing Opcodes |
|----------|-----------------|
| Array ops | `array_load`, `array_store`, `array_len`, `array_slice` |
| List extras | `list_clear`, `list_to_slice` |
| Map extras | `map_clear`, `map_keys`, `map_values` |
| Math | `fn_abs`, `fn_sqrt`, `fn_sin`, etc. |
| Type conv | `to_int`, `to_str`, `to_bool`, `to_char` |

---

## Gap Analysis: IR Operations

### ir.cot IROps vs Emission Coverage

The IR defines 60+ operations in `IROp` enum. Many have no corresponding emission in `emit.cot`:

| IROp | emit.cot Status |
|------|-----------------|
| `VariantConstruct` | No opcode emission (marked ✅ in feature-parity but no OP_VARIANT_CONSTRUCT) |
| `VariantGetTag` | No opcode emission |
| `VariantGetPayload` | No opcode emission |
| `MakeClosure` | No opcode emission |
| `Select` | No opcode emission |
| `SliceNew` | No opcode emission |
| `IsNull` | No opcode emission |

---

## Import System Gap

**Status:** Documented in `16-import-system.md` but NOT implemented.

**Impact:** Cannot compile cot-compiler as a whole (10 source files require imports).

**Current Workaround:** Single-file compilation only.

**Required:**
- `module.cot` - Module infrastructure (~400 lines)
- Type checker integration (~100 lines)
- Driver integration (~100 lines)

---

## Native Codegen Gap

**Status:** ~30% complete based on file existence.

**Files Present:**
- `emit_native.cot` - exists but incomplete
- `asm_arm64.cot` - exists but incomplete
- `object_macho.cot` - exists but incomplete

**Missing:**
- Full opcode → ARM64 mapping
- Register allocation
- ABI compliance (macOS ARM64)
- Linker integration

---

## Prioritized Action Plan

### Phase 1: Opcode Parity (P0 Critical)

**Goal:** Emit all opcodes needed for self-compilation.

**Task 1.1: Add Variant Opcodes**
```
Files: emit.cot
Add: OP_VARIANT_CONSTRUCT = 0x8A
     OP_VARIANT_GET_TAG = 0x8B
     OP_VARIANT_GET_PAYLOAD = 0x8C
Emit functions: emitVariantConstruct(), emitVariantGetTag(), emitVariantGetPayload()
```

**Task 1.2: Add Stack Pointer Opcodes**
```
Files: emit.cot
Add: OP_GET_LOCAL_PTR = 0x7A
     OP_LOAD_INDIRECT = 0x7B
     OP_STORE_INDIRECT = 0x7C
     OP_PTR_OFFSET = 0x59
Emit functions: emitGetLocalPtr(), emitLoadIndirect(), emitStoreIndirect(), emitPtrOffset()
```

**Task 1.3: Add ARC Opcodes**
```
Files: emit.cot
Add: OP_ARC_RETAIN = 0xF5
     OP_ARC_RELEASE = 0xF6
     OP_ARC_MOVE = 0xF7
Emit functions: emitArcRetain(), emitArcRelease(), emitArcMove()
```

**Task 1.4: Add Closure Opcodes**
```
Files: emit.cot
Add: OP_MAKE_CLOSURE = 0xF8
     OP_CALL_CLOSURE = 0xF9
Emit functions: emitMakeClosure(), emitCallClosure()
```

**Task 1.5: Wire IR→Bytecode in emitIR**
```
Files: emit.cot
Add switch cases in emitInstruction() for:
- IROp.VariantConstruct → emitVariantConstruct
- IROp.VariantGetTag → emitVariantGetTag
- IROp.VariantGetPayload → emitVariantGetPayload
- IROp.MakeClosure → emitMakeClosure
```

### Phase 2: Import System

**Goal:** Compile multi-file projects (cot-compiler has 10+ files).

**Task 2.1: Create module.cot**
- ModuleCache struct
- Path resolution
- Module loading
- Dependency ordering
- Cycle detection

**Task 2.2: Type Checker Integration**
- Add module_cache to TypeChecker
- Handle ImportStmt
- Collect exports

**Task 2.3: Driver Integration**
- Multi-file compilation loop
- Combined bytecode output

### Phase 3: Additional Opcodes (P1)

**Task 3.1: Struct-in-Collection**
```
Add: OP_LIST_PUSH_STRUCT = 0xB5
     OP_LIST_GET_STRUCT = 0xB6
     OP_LIST_SET_STRUCT = 0xB8
```

**Task 3.2: String Operations**
```
Add: OP_STR_INDEX = 0x92
     OP_STR_SLICE = 0x93
     OP_STR_TRIM = 0x95
     OP_STR_FIND = 0x98
```

**Task 3.3: Type Operations**
```
Add: OP_IS_NULL = 0x57
     OP_IS_TYPE = 0x5C
     OP_SELECT = 0x58
```

### Phase 4: Native Codegen

**Goal:** Complete ARM64 backend for Stage 1 bootstrap.

**Task 4.1: Complete asm_arm64.cot**
- All arithmetic instructions
- All control flow
- All memory operations

**Task 4.2: Complete emit_native.cot**
- Opcode dispatch
- Register allocation
- Prologue/epilogue

**Task 4.3: Complete object_macho.cot**
- Mach-O header
- Sections
- Symbol table
- Relocations

---

## Verification Milestones

### Milestone 1: Single-File Parity
```bash
# cot-compiler compiles itself (single file test)
cot compile src/emit.cot -o /tmp/emit.cbo
# Compare output structure with Zig compiler output
```

### Milestone 2: Import System Works
```bash
# Multi-file compilation
cot compile src/driver.cot -o /tmp/driver.cbo
# Should successfully compile all 10 source files
```

### Milestone 3: Self-Compilation
```bash
# Stage 1: Zig-cot compiles cot-compiler
cot compile src/driver.cot -o /tmp/stage1.cbo

# Stage 2: cot-compiler compiles itself
cot run /tmp/stage1.cbo -- compile src/driver.cot -o /tmp/stage2.cbo

# Verify identical output
diff /tmp/stage1.cbo /tmp/stage2.cbo
```

### Milestone 4: Native Bootstrap
```bash
# Compile to native
cot-rs compile /tmp/driver.cbo -o cot-native

# Self-compile natively
./cot-native compile src/driver.cot --native -o cot-native-2

# Verify
diff cot-native cot-native-2
```

---

## Effort Estimate

| Phase | Tasks | Complexity | Lines | Status |
|-------|-------|------------|-------|--------|
| Phase 1: P0 Opcodes | 5 tasks | Medium | ~300 | **COMPLETE** |
| Phase 2: Import System | 3 tasks | High | ~600 | Pending |
| Phase 3: P1/P2 Opcodes | 3 tasks | Low | ~300 | **COMPLETE** |
| Phase 4: Native Codegen | 3 tasks | Very High | ~2000 | Pending |
| **Total** | 14 tasks | | ~3200 | **2/4 Complete** |

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Opcode semantics mismatch | High | Test each opcode against Zig VM behavior |
| Import cycle complexity | Medium | Start with acyclic subset of cot-compiler |
| Native ABI issues | High | Use cot-rs Cranelift as reference |
| IR→Bytecode mapping errors | Medium | Compare bytecode output byte-by-byte |

---

## Completed Actions (2026-01-09)

All opcode and emit function additions have been completed:

| Category | Opcodes Added | Emit Functions Added |
|----------|---------------|---------------------|
| **P0: Stack Pointers** | `GET_LOCAL_PTR`, `LOAD_INDIRECT`, `STORE_INDIRECT`, `PTR_OFFSET` | 4 functions |
| **P0: Variants** | `VARIANT_CONSTRUCT`, `VARIANT_GET_TAG`, `VARIANT_GET_PAYLOAD` | 3 functions |
| **P0: ARC** | `ARC_RETAIN`, `ARC_RELEASE`, `ARC_MOVE` | 3 functions |
| **P0: Closures** | `MAKE_CLOSURE`, `CALL_CLOSURE` | 2 functions |
| **P1: Comparison Jumps** | `JEQ`, `JNE`, `JLT`, `JGE`, `JMP32`, `LOOP_START`, `LOOP_END` | 7 functions |
| **P1: Inc/Dec** | `INCR`, `DECR` | 2 functions |
| **P1: Type Ops** | `IS_NULL`, `SELECT`, `IS_TYPE` | 3 functions |
| **P1: String Ops** | `STR_INDEX`, `STR_SLICE`, `STR_TRIM`, `STR_UPPER`, `STR_LOWER`, `STR_FIND`, `STR_REPLACE`, `STR_SETCHAR`, `STR_SLICE_STORE` | 9 functions |
| **P1: String Compare** | `CMP_STR_EQ`, `CMP_STR_LT`, `CMP_STR_NE`, `CMP_STR_LE`, `CMP_STR_GT`, `CMP_STR_GE` | 6 functions |
| **P1: Struct Collections** | `LIST_PUSH_STRUCT`, `LIST_GET_STRUCT`, `LIST_POP_STRUCT`, `LIST_SET_STRUCT`, `MAP_SET_STRUCT`, `MAP_GET_STRUCT` | 6 functions |
| **P1: Call Variants** | `CALL_INDIRECT`, `CALL_DYNAMIC`, `PUSH_ARG`, `PUSH_ARG_REG`, `POP_ARG` | 5 functions |
| **P1: List/Map Extras** | `LIST_CLEAR`, `LIST_TO_SLICE`, `MAP_CLEAR`, `MAP_KEYS`, `MAP_VALUES`, `MAP_GET_AT`, `MAP_SET_AT`, `MAP_KEY_AT` | 8 functions |
| **P2: Arrays** | `ARRAY_LOAD`, `ARRAY_STORE`, `ARRAY_LEN`, `ARRAY_SLICE`, `ARRAY_LOAD_OPT` | 4 functions |
| **P2: Type Conv** | `TO_INT`, `TO_STR`, `TO_BOOL`, `TO_DEC`, `TO_CHAR`, `TO_FIXED_STRING`, `FORMAT_DECIMAL`, `PARSE_DECIMAL` | 8 functions |
| **P2: Record Extras** | `FREE_RECORD`, `CLEAR_RECORD`, `ALLOC_BUFFER` | 3 functions |
| **P2: Weak Refs** | `WEAK_REF`, `WEAK_LOAD` | 2 functions |
| **P2: Trait Objects** | `MAKE_TRAIT_OBJECT`, `CALL_TRAIT_METHOD` | 2 functions |
| **P2: I/O** | `READLN`, `READKEY`, `LOG` | 3 functions |
| **P2: Debug** | `DEBUG_BREAK`, `ASSERT` | 2 functions |

**Result:** emit.cot now has **150 opcode constants** and **171 emit functions** (up from ~50 opcodes).

---

## Next Immediate Actions

1. ~~Add P0 opcode constants to emit.cot~~ **DONE**
2. ~~Add emit functions for each P0 opcode~~ **DONE**
3. ~~Wire up IR→Bytecode in translateInst switch~~ **DONE** (77/77 IROps mapped)
4. **Test with simple sum type program**
5. **Implement import system**

### IR→Bytecode Wiring Complete (2026-01-09)

All 77 IROp variants now have corresponding switch cases in `translateInst()`:

| Category | IROps Wired |
|----------|-------------|
| Memory | Alloca, Load, Store, FieldPtr, IndexPtr |
| Arithmetic | IAdd, ISub, IMul, SDiv, UDiv, SRem, URem, INeg |
| Float | FAdd, FSub, FMul, FDiv, FNeg, FCmp |
| Bitwise | BAnd, BOr, BXor, BNot, IShl, SShr, UShr |
| Comparison | ICmp |
| Logical | LogAnd, LogOr, LogNot |
| Control Flow | Jump, BrIf, BrTable, Ret, Call |
| Constants | IConst, FConst, StrConst, BoolConst, NullConst |
| Conversions | Bitcast, SExtend, UExtend, IReduce, IntToFloat, FloatToInt |
| String | StrConcat, StrCompare, StrLen |
| Optional | WrapOptional, UnwrapOptional, IsNull |
| Arrays | ArrayLoad, ArrayStore, ArrayLen, SliceNew |
| List | ListNew, ListPush, ListPop, ListGet, ListSet, ListLen |
| Map | MapNew, MapSet, MapGet, MapHas, MapDelete, MapLen |
| Select | Select |
| Debug | DebugLine |
| Error | SetHandler, ClearHandler, ErrThrow |
| **Variants** | VariantConstruct, VariantGetTag, VariantGetPayload |
| **Closures** | MakeClosure |

---

## Files Reference

| File | Purpose |
|------|---------|
| `/Users/johnc/cotlang/cot-compiler/src/emit.cot` | Bytecode emission (needs opcode additions) |
| `/Users/johnc/cotlang/cot-compiler/src/ir.cot` | IR definitions (IROp enum) |
| `/Users/johnc/cotlang/cot-compiler/src/lower.cot` | AST→IR lowering |
| `/Users/johnc/cotlang/cot/src/runtime/bytecode/opcodes.zig` | Reference opcode definitions |
| `/Users/johnc/cotlang/cot/src/ir/emit_bytecode.zig` | Reference bytecode emission |
