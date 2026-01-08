# Compiler Bugs Found During Sum Type Implementation

**Created:** 2026-01-08

## Bug 1: Error Line Number Off By 1 Line - FIXED ✅

**Root cause:** In `parser/parser.zig`, `currentLoc()` was called AFTER consuming the field identifier token, so it pointed to the next line's token.

**Fix:** Use `field_token.line` and `field_token.column` instead of `currentLoc()` when creating member expressions (lines 1610-1612 and 1639-1641).

**Commit:** 2026-01-08

---

## ~~Bug 2: Wrong Field Name in Error Message~~ - NOT A BUG

This was a misinterpretation. The error correctly showed `'name'` because that was the field being accessed at `callee.object.*.name`. The confusion arose because the wrong LINE was reported (Bug 1), making it look like the field name was wrong.

---

## Bug 3: Second Struct Field Returns Null (RUNTIME) - FIXED ✅

**Reproduction:**
```cot
struct Foo {
    name: string,
    field_name: string,
}

fn main() {
    var f = Foo{ .name = "n", .field_name = "fn" }
    println(f.name)        // was printing "n" ✓
    println(f.field_name)  // was printing "null" ✗, now prints "fn" ✓
}
```

**Root cause:** Two related issues:
1. **Type inference bug**: `var f = Foo{...}` inferred type `*Foo` (pointer) instead of `Foo` (struct), causing the aliasing optimization to not trigger
2. **Semantic confusion**: `emitAlloca` for structs put `struct_ptr.id` in `value_slots` at the same slot as the struct fields. When `getValueInReg` tried to load the pointer, it loaded the first field value instead.

**Fix (two parts):**
1. `src/ir/lower_stmt.zig`: Fixed type inference to unwrap pointer-to-struct types when inferring from struct/array init expressions
2. `src/ir/emit_bytecode.zig` + `emit_instruction.zig`: Added `struct_base_slots` map to track struct base slot locations separately from loadable values. Struct pointers are compile-time concepts (slot references), not runtime values that can be loaded.

---

## Bug 4: No Optional Pointer Unwrap After Null Check - NOT A BUG ✅

**Original report:**
```cot
var opt: ?*Foo = &f
if (opt != null) {
    const ptr: *Foo = opt  // ERROR: cannot assign ?*Foo to *Foo
}
```

**Investigation (2026-01-08):** Tested in the Zig compiler and the code compiles and runs correctly:
```cot
struct Foo { value: i64 }
fn main() {
    var f = Foo{ .value = 42 }
    var opt: ?*Foo = &f
    if (opt != null) {
        const ptr: *Foo = opt  // Works!
        println(ptr.value)     // Prints: 42
    }
}
```

**Conclusion:** The Zig-based compiler allows implicit coercion from `?*T` to `*T`. This may be intentional (simpler semantics) or may need type narrowing in the future. The original error may have been from the self-hosted compiler (cot-compiler) which has its own type checker.

---

---

## Bug 5: String Concatenation with list_get Clobbering - FIXED ✅

**Reproduction:**
```cot
fn main() {
    var args = process_args()
    var i: i64 = 0
    println(string(i) + ": " + args.get(i))  // Output was: "0: 0: /path/to/program"
}                                             // Expected:  "0: /path/to/program"
```

**Root cause:** `emitListGet` used hardcoded `dest_reg = 2`. The intermediate string concatenation result `"0: "` was in r2. When `list_get` executed, it clobbered r2 with the list element BEFORE `setLastResult()` could spill the old value. The second `str_concat` then used the wrong value.

**Fix:** Added `prepareDestReg()` function to `emit_bytecode.zig` that spills any existing value in a destination register BEFORE the instruction clobbers it. Applied to:
- `emitListGet()` at `emit_instruction.zig:2106`
- `emitListPop()` at `emit_instruction.zig:2061`

**Files modified:**
- `cot/src/ir/emit_bytecode.zig` - Added `prepareDestReg()` function
- `cot/src/ir/emit_instruction.zig` - Call `prepareDestReg()` before `list_get` and `list_pop`

---

## Bug 6: Rust Runtime process_args() Return Type Mismatch - FIXED ✅

**Problem:** Rust runtime's `process_args()` returned a newline-joined string, while Zig runtime returned `List<string>`. This caused bytecode compiled by Zig to fail on Rust runtime.

**Fix:** Updated Rust runtime to return `List<string>`:
1. Added `ListCreator` and `ListPusher` callback types to `NativeContext`
2. Added `list_creator_fn()` and `list_pusher_fn()` bridge functions to VM
3. Updated `process_args()` to use `ctx.create_list()` and `ctx.list_push()`
4. Updated `needs_arc()` to exclude registry-based List type (type_id 19)
5. Updated `arc.rs` release to skip registry-based lists

**Files modified:**
- `cot-rs/src/native/mod.rs` - Extended NativeContext
- `cot-rs/src/native/system.rs` - Updated process_args()
- `cot-rs/src/vm/mod.rs` - Added list helper functions
- `cot-rs/src/vm/ops_native.rs` - Updated with_vm() calls
- `cot-rs/src/value.rs` - Updated needs_arc()
- `cot-rs/src/arc.rs` - Fixed List handling

---

## Priority Order

1. **Bug 1 + Bug 2** - These are related (same error pathway) - fix together
2. **Bug 3** - Struct field access broken for multi-field structs
3. **Bug 4** - Design decision - may need language feature

## Test Files

- `/Users/johnc/cotlang/cot-compiler/src/test_field3.cot` - Reproduces bugs 1 & 2
- `/tmp/test_field_access2.cot` - Reproduces bug 3
- `/tmp/bug_inline.cot` - Reproduces bug 5 (string concat with list_get)
