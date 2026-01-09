# String Indexing Feature Plan

**Created:** 2026-01-09
**Status:** COMPLETE

---

## Goal

Add array-style indexing for strings: `s[i]` returns byte value (i64) at index i.

This is more intuitive and consistent with Zig/Rust/Go than the current `s.char_at(i)` method.

---

## Current State

- `s[0..3]` - Range indexing works (substring)
- `s.char_at(i)` - Method call works (legacy, still supported)
- `s[i]` - **IMPLEMENTED** - returns byte value (i64)

---

## Implementation Tasks

### 1. IR Instruction Definition (`ir/ir.zig`)
- [x] Add `str_byte_at` to the IR instruction enum
- [x] Define operands: `string: Value`, `index: Value`, `result: Value`

### 2. Lowerer (`ir/lower_expr.zig`)
- [x] Add string type check in `lowerIndex` function (line 1440)
- [x] Check both `.string` type and `[N]u8` byte arrays (string literals)
- [x] Emit `str_byte_at` instruction for string indexing
- [x] Return result with type `i64` (byte value)

### 3. Bytecode Emitter (`ir/emit_bytecode.zig`, `emit_instruction.zig`)
- [x] Add `emitStrByteAt` function to emit_instruction.zig (line 902)
- [x] Handle `str_byte_at` IR instruction in emit_bytecode.zig (line 875)
- [x] Uses existing `str_index` opcode (0x92)

### 4. VM Opcode Handler (`runtime/bytecode/vm.zig`, `vm_opcodes.zig`)
- [x] Register `str_index` opcode in dispatch table (vm.zig line 1421)
- [x] Implement `op_str_index` handler (vm_opcodes.zig line 1589)
- [x] Bounds checking returns 0 for out-of-bounds access

### 5. Documentation (`SYNTAX.md`)
- [x] Update Strings section with `s[i]` syntax (line 217)
- [x] Note that it returns byte value (i64)
- [x] Keep `char_at` documented as legacy alternative

---

## Code Locations

| File | Function/Section | Change |
|------|------------------|--------|
| `cot/src/ir/ir.zig` | `Instruction` enum | Added `str_byte_at` variant |
| `cot/src/ir/ir.zig` | `StrByteAt` struct | Added struct definition |
| `cot/src/ir/lower_expr.zig` | `lowerIndex()` line 1440 | Added string/byte-array case |
| `cot/src/ir/emit_instruction.zig` | `emitStrByteAt()` line 902 | Added emission function |
| `cot/src/ir/emit_bytecode.zig` | instruction switch line 875 | Added `str_byte_at` case |
| `cot/src/runtime/bytecode/vm.zig` | dispatch_table line 1421 | Registered `str_index` |
| `cot/src/runtime/bytecode/vm_opcodes.zig` | `op_str_index()` line 1589 | Implemented handler |
| `SYNTAX.md` | Strings section line 217 | Documented `s[i]` syntax |

---

## Example

```cot
var s = "hello"
var byte = s[0]     // 72 (ASCII 'H')
var byte2 = s[4]    // 111 (ASCII 'o')

// With variable index
var i = 2
println(s[i])       // 108 (ASCII 'l')

// Out of bounds returns 0
println(s[10])      // 0
```

---

## Testing Results

All tests pass:
1. ✅ `s[0]` returns 72 (ASCII 'H')
2. ✅ `s[4]` returns 111 (ASCII 'o')
3. ✅ `s[10]` returns 0 (out of bounds)
4. ✅ Works with variable index: `s[i]`
5. ✅ Works with string literals and variables
