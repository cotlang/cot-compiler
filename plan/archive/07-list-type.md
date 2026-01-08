# Plan: Implement List<T> Built-in Type

## Status: ✅ COMPLETE (2025-01-06)

## Goal
Add `List<T>` as a runtime-managed generic container, matching the existing `Map<K, V>` pattern.

## Usage Example
```cot
const list: List<int> = List.new()
list.push(10)
list.push(20)
list.push(30)

const first = list.get(0)    // 10
const length = list.len()    // 3
const last = list.pop()      // 30
list.set(0, 99)              // change first element
list.clear()                 // remove all
```

## Operations

| Operation | Syntax | Description |
|-----------|--------|-------------|
| Create | `List.new()` | Empty list (type from annotation) |
| Push | `list.push(item)` | Add to end |
| Pop | `list.pop()` | Remove & return last |
| Get | `list.get(i)` | Get by index |
| Set | `list.set(i, x)` | Set by index |
| Length | `list.len()` | Get count |
| Clear | `list.clear()` | Remove all |

## Implementation Steps

### Phase 1: IR Type System ✅ COMPLETE
**File:** `src/ir/ir.zig`

- [x] Add `list: *const ListType` variant to `Type` union (like `map: *const MapType`)
- [x] Define `ListType` struct:
  ```zig
  pub const ListType = struct {
      element_type: *const Type,
  };
  ```

### Phase 2: IR Instructions ✅ COMPLETE
**File:** `src/ir/ir.zig`

Add instruction variants:
- [x] `list_new` - Create empty list
- [x] `list_push` - Push item
- [x] `list_pop` - Pop item
- [x] `list_get` - Get by index
- [x] `list_set` - Set by index
- [x] `list_len` - Get length
- [x] `list_clear` - Clear all items

### Phase 3: Type Lowering ✅ COMPLETE
**File:** `src/ir/lower_expr.zig`

- [x] Handle `List<T>` generic instantiation → create `ListType`
- [x] Pattern match on "List" base type name (like "Map", "Option", "Result")

### Phase 4: Expression Lowering ✅ COMPLETE
**File:** `src/ir/lower_expr.zig`

- [x] `List.new()` static method → `list_new` instruction
- [x] `list.push(x)` method call → `list_push` instruction
- [x] `list.pop()` method call → `list_pop` instruction
- [x] `list.clear()` method call → `list_clear` instruction
- [x] `list.get(i)` method call → `list_get`
- [x] `list.set(i, x)` method call → `list_set`
- [x] `list.len()` method call → `list_len`

### Phase 5: Bytecode Opcodes ✅ COMPLETE
**File:** `src/runtime/bytecode/opcodes.zig`

Add opcodes:
- [x] `list_new` (0xED)
- [x] `list_push` (0xEE)
- [x] `list_pop` (0xEF)
- [x] `list_get` (0xFD)
- [x] `list_set` (0xFF)
- [x] `list_len` (0xB3)
- [x] `list_clear` (0xB4)

### Phase 6: Bytecode Emission ✅ COMPLETE
**File:** `src/ir/emit_bytecode.zig`

- [x] Emit bytecode for each list IR instruction

### Phase 7: VM Runtime ✅ COMPLETE
**File:** `src/runtime/bytecode/vm.zig` and `vm_opcodes.zig`

- [x] Implement `List` runtime representation in `value.zig`
- [x] Implement opcode handlers for all list operations
- [x] Memory management via arena allocator

### Phase 8: Native Function Bindings
**File:** `src/runtime/native/`

- N/A - Using opcodes directly

### Phase 9: Rust Runtime ✅ COMPLETE
**File:** `~/cotlang/cot-rs/`

- [x] Add `List` type to Rust runtime (`value.rs`)
- [x] Implement list opcode handlers (`ops_collection.rs`)
- [x] Match Zig VM behavior exactly

## Reference: How Map is Implemented

### Map IR Type (ir.zig)
```zig
pub const MapType = struct {
    key_type: *const Type,
    value_type: *const Type,
};
```

### Map Opcodes
- map_new, map_set, map_get, map_delete, map_has
- map_len, map_clear, map_keys, map_values, map_key_at

### Map Runtime
- Stored as `Value.map` variant
- Backed by ordered hash map

### Phase 10: Struct Support (List<struct>) ✅ COMPLETE
**Date:** 2025-01-06

When storing structs in a List, each struct spans multiple stack slots (one per field).
The original list opcodes only captured a single value, causing field loss.

**Solution:** Added struct-aware list opcodes that box/unbox multi-slot structs:

**Zig Runtime (`~/cotlang/cot/`):**
- Added `StructBox` type (type_id=20) to `value.zig`
- Added 4 new opcodes to `opcodes.zig`:
  - `list_push_struct` (0xB5) - boxes stack slots → pushes to list
  - `list_get_struct` (0xB6) - retrieves StructBox → expands to registers
  - `list_pop_struct` (0xB7) - pops StructBox → expands to stack slots
  - `list_set_struct` (0xB8) - boxes stack slots → replaces list element
- Modified `emit_instruction.zig` to detect struct types and emit appropriate opcodes
- Implemented VM handlers in `vm_opcodes.zig` with proper ARC retain/release
- Added StructBox handling in `arc.zig` for memory management

**Rust Runtime (`~/cotlang/cot-rs/`):**
- Added `StructBox` struct and `STRUCT_BOX_TYPE_ID` to `value.rs`
- Added opcode definitions to `bytecode/opcodes.rs`
- Implemented handlers in `vm/ops_collection.rs`
- Added `retain(Value)` and `release(Value)` functions to `arc.rs`

## Testing ✅ COMPLETE

- [x] Test file: `tests/test_list.cot`
- [x] Basic push/pop/get/set/len/clear
- [x] List<struct> - structs with multiple fields (int + string) ✅ FIXED
- [ ] Nested lists (List<List<i64>>) - future

## Dependencies

None - Map already proves the pattern works.

## Estimated Scope

Similar to Map implementation. Can reference existing Map code throughout.

| Phase | Est. Complexity |
|-------|-----------------|
| IR Type | Small |
| IR Instructions | Small |
| Type Lowering | Small |
| Expr Lowering | Medium |
| Bytecode | Small |
| VM Runtime | Medium |
| **Total** | Medium |
