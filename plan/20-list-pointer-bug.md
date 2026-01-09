# List<*T> Pointer Storage Bug

**Created:** 2026-01-09
**Status:** COMPLETE - All bugs fixed

## Problem Statement

When storing pointers in a `List<*T>` and retrieving them, field access through the retrieved pointer returns incorrect values.

## Bug 1: list_push/get using struct opcodes (FIXED)

Fixed in `emit_instruction.zig` - removed the condition that treated `*Struct` same as `Struct`.
Now `list_get` correctly returns the pointer value.

## Bug 2: Field access through pointer not generating load_field (FIXED)

When accessing `retrieved.field` where `retrieved` is type `*Struct` from `List<*T>.get()`,
the compiler wasn't generating `load_field` opcodes.

**Fix in `emit_bytecode.zig`:**
- Added `HeapFieldPtrInfo` struct to track heap field pointer accesses
- Added `heap_field_ptrs` map to BytecodeEmitter
- Modified `emitFieldPtr` to track heap field pointers when struct_ptr isn't in slots
- Modified `getValueInReg` and `emitValueToReg` to emit `load_field` for heap field pointers

**Fix in `emit_instruction.zig`:**
- Modified `emitFieldPtr` to track heap field pointers via `heap_field_ptrs` map
- Modified `emitLoad` to propagate `heap_field_ptrs` info from ptr to result

## Bug 3: Register clobbering for second field access (FIXED)

When accessing multiple fields on a struct pointer from `List<*T>.get()`, the first field
access worked but subsequent ones failed because the struct pointer was clobbered.

**Root Cause:**
The type inference in `lowerLetDecl` was stripping the pointer type:
- `var retrieved = items.get(0)` where `.get()` returns `*Item`
- Type was inferred as `struct(Item)` instead of `*Item`
- The aliasing optimization was applied (designed for struct literals)
- No alloca or store was created for the variable
- The pointer value couldn't be reloaded after register clobbering

**Fix in `lower_stmt.zig`:**
1. Type inference: Don't strip pointer type for struct pointers (only for arrays)
2. Aliasing optimization: Don't alias struct pointers (only arrays)

Now when declaring `var retrieved = items.get(0)`:
1. Type is correctly `*Item` (pointer to struct)
2. An alloca is created for the pointer variable
3. The pointer value is stored to a local slot
4. Field accesses reload the pointer from the slot when needed

## Test Results

Test file `/tmp/test_list_ptr.cot`:
```cot
struct Item {
    name: string,
    value: i64,
}

fn main() {
    var items = new List<*Item>
    var item1 = new Item{ .name = "first", .value = 1 }
    println("item1.name: " + item1.name)
    items.push(item1)
    println("items.len: " + string(items.len()))
    var retrieved = items.get(0)
    println("retrieved type...")
    println("retrieved.name: " + retrieved.name)
    println("retrieved.value: " + string(retrieved.value))
}
```

Output (CORRECT):
```
item1.name: first
items.len: 1
retrieved type...
retrieved.name: first
retrieved.value: 1
```

## Files Modified

- `cot/src/ir/emit_bytecode.zig` - Added heap field pointer tracking
- `cot/src/ir/emit_instruction.zig` - Modified emitFieldPtr, emitLoad, emitStore
- `cot/src/ir/lower_stmt.zig` - Fixed type inference and aliasing optimization
