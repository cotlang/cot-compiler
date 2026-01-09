# Native Codegen Completion Plan

**Created:** 2026-01-09
**Updated:** 2026-01-09
**Status:** Priority 4 Complete (~75% opcode coverage), All Advanced Features Implemented

---

## Current State

| File | Lines | Status |
|------|-------|--------|
| `emit_native.cot` | 1650+ | ~75% (85+ opcodes) |
| `asm_arm64.cot` | 738 | ~95% core instructions |
| `object_macho.cot` | 600+ | ~95% complete |
| `runtime/cot_runtime.zig` | 680+ | Complete - Zig runtime library |
| `runtime/build.zig` | 47 | Zig build configuration |

### Opcodes Currently Implemented (85+)

| Category | Opcodes |
|----------|---------|
| Core | Nop, Halt |
| Registers | Mov, MovI, MovI16, LoadNull, LoadTrue, LoadFalse, LoadConst |
| Locals | LoadLocal, StoreLocal, LoadLocal16, StoreLocal16 |
| Globals | LoadGlobal, StoreGlobal |
| Stack Pointers | GetLocalPtr, LoadIndirect, StoreIndirect |
| Arithmetic | Add, Sub, Mul, Div, Mod, Neg, Incr, Decr |
| Comparison | CmpEq, CmpNe, CmpLt, CmpLe, CmpGt, CmpGe |
| Bitwise | BitAnd, BitOr, BitXor, BitNot, Shl, Shr |
| Logical | LogAnd, LogOr, LogNot, IsNull, Select |
| Control | Jmp, Jz, Jnz, Jeq, Jne, Jlt, Jge |
| Calls | Call, Ret, RetVal |
| Records | NewRecord, LoadField, StoreField (runtime calls) |
| Strings | StrConcat, StrLen (runtime calls) |
| Lists | ListNew, ListPush, ListPop, ListGet, ListSet, ListLen (runtime calls) |
| Maps | MapNew, MapSet, MapGet, MapHas, MapDelete, MapLen (runtime calls) |
| Closures | MakeClosure, CallClosure (runtime calls) |
| Variants | VariantConstruct, VariantGetTag, VariantGetPayload (runtime calls) |
| Error Handling | SetErrorHandler, ClearErrorHandler, ThrowOp (runtime calls) |
| I/O | Print, Println (runtime calls) |
| Debug | DebugLine, DebugBreak |

---

## Phase 1: Complete CPU-Only Operations

These opcodes can be implemented purely with ARM64 instructions.

### 1.1 Missing Logical/Bitwise Operations

```
BitNot     - MVN instruction
Shl        - LSL instruction
Shr        - LSR/ASR instruction
LogAnd     - Compare + conditional set
LogOr      - Compare + conditional set
LogNot     - Compare + conditional set
IsNull     - Compare with 0
Select     - CSEL instruction
```

### 1.2 Missing ARM64 Instructions in asm_arm64.cot

```
mvn        - bitwise NOT
lsl        - logical shift left
lsr        - logical shift right
asr        - arithmetic shift right
udiv       - unsigned divide
csel       - conditional select
ldrb/strb  - byte load/store
ldrh/strh  - halfword load/store
adrp       - PC-relative page address
```

### 1.3 LoadConst Implementation

LoadConst requires:
1. Data section in Mach-O for constant pool
2. ADRP + ADD/LDR to load from data section
3. Symbol relocations

---

## Phase 2: Runtime Library Integration ✅ COMPLETE

Complex operations need a runtime library. **Decision: Zig Runtime (Option D)**

### Option D: Native Zig Runtime ✅ IMPLEMENTED
Create a modern Zig library with functions like:
- `cot_list_new()` → `List<T>`
- `cot_list_push(list, val)` → void
- `cot_map_new()` → `Map<K,V>`
- etc.

**Benefits:**
- Memory safety via GeneralPurposeAllocator
- Modern approach aligned with Cot's philosophy
- Better debugging and error detection
- Cleaner integration with future Zig-based tooling

**Implementation:** `runtime/cot_runtime.zig` (680+ lines)
- Reference counting with `cot_retain`/`cot_release`
- List, Map, String, Record operations
- Closure operations (cot_closure_new, cot_closure_get_fn, cot_closure_get_env)
- Variant operations (cot_variant_new, cot_variant_get_tag, cot_variant_get/set_payload)
- Error handling (cot_set_error_handler, cot_clear_error_handler, cot_throw, cot_get_error)
- All tests passing

---

## Phase 3: Implementation Order

### Priority 1: CPU-Only (Can Do Now)
1. ✅ Add missing ARM64 instructions to asm_arm64.cot
2. ✅ Implement BitNot, Shl, Shr in emit_native.cot
3. ✅ Implement LogAnd, LogOr, LogNot
4. ✅ Implement IsNull, Select
5. ✅ Implement LoadConst (basic integers)

### Priority 2: Globals and Constants
1. ✅ Implement LoadGlobal, StoreGlobal (ADRP + LDR/STR with relocations)
2. ✅ Implement LoadConst for strings (ADRP + ADD with relocation tracking)
3. ✅ Implement LoadConst for floats (ADRP + LDR with relocation tracking)
4. ✅ Implement comparison jumps (Jeq, Jne, Jlt, Jge)

### Priority 3: Runtime Library Calls
1. ✅ Create libcot_runtime.c with list/map/string/record operations
2. ✅ Add RuntimeFn enum and emitRuntimeCall helper
3. ✅ Implement NewRecord → calls `cot_record_new`
4. ✅ Implement LoadField/StoreField → calls `cot_record_get/set_field`
5. ✅ Implement List* → calls `cot_list_*`
6. ✅ Implement Map* → calls `cot_map_*`
7. ✅ Implement String* → calls `cot_str_*`
8. ✅ Implement Print/Println → calls `cot_print*`

### Priority 4: Advanced Features ✅ COMPLETE
1. ✅ Error handling (SetErrorHandler, ClearErrorHandler, ThrowOp) - runtime support
2. ✅ Stack pointer operations (GetLocalPtr, LoadIndirect, StoreIndirect)
3. ✅ Closures (MakeClosure, CallClosure) - MakeClosure complete, CallClosure framework
4. ✅ Variants (VariantConstruct, VariantGetTag, VariantGetPayload) - runtime support

---

## Phase 4: Testing

### 4.1 Simple Test (No Runtime)
```cot
fn add(a: i64, b: i64) i64 {
    return a + b
}

fn main() i64 {
    return add(10, 20)
}
```

### 4.2 With Locals
```cot
fn factorial(n: i64) i64 {
    if (n <= 1) { return 1 }
    return n * factorial(n - 1)
}
```

### 4.3 With Runtime Library
```cot
fn main() {
    var list = new List<i64>
    list.push(1)
    list.push(2)
    println(list.len())
}
```

---

## Deliverables

1. **asm_arm64.cot additions**
   - `mvn`, `lsl`, `lsr`, `asr`, `udiv`, `csel`
   - `adrp`, `ldrb`, `strb`

2. **emit_native.cot additions**
   - ~50 more opcode handlers
   - Runtime library call mechanism
   - Data section for constants

3. **object_macho.cot additions**
   - External symbol references
   - GOT entries for runtime functions

4. **libcot_runtime.c** (new)
   - ~500 lines of C for runtime support

---

## Timeline Estimate

| Phase | Tasks | Effort |
|-------|-------|--------|
| Phase 1 | CPU-only ops | Low |
| Phase 2 | Runtime design | Medium |
| Phase 3 | Implementation | High |
| Phase 4 | Testing | Medium |

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| ABI mismatch | Use standard ARM64 AAPCS64 calling convention |
| Runtime linking | Use position-independent code |
| Memory management | Leverage existing Zig runtime or simple bump allocator |
