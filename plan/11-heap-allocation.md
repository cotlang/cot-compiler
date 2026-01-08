# Heap Allocation (`new` keyword) Implementation Plan

**Created:** 2026-01-07
**Status:** PLANNING
**Priority:** HIGH - Enables cleaner AST design, unlocks general-purpose programming

## Background

The Cot runtime already has production-ready ARC (automatic reference counting):
- `arc.zig` - refcounting with retain/release
- `WeakRegistry` - weak references with auto-invalidation
- `cycle_collector.zig` - handles circular references
- `StructBox` - heap-allocated user structs
- VM opcodes: `new_record`, `arc_retain`, `arc_release`, `weak_ref`

**What's missing:** Language syntax to expose this to users.

## Syntax Options

### Option A: `new` Keyword (Recommended)
```cot
// Heap-allocated struct, returns *Point (ARC-managed)
var p = new Point{ .x = 10, .y = 20 }

// Compare to stack-allocated:
var p = Point{ .x = 10, .y = 20 }  // Stack, type is Point
```

**Pros:** Familiar (C++/Java/C#/Go), clear intent, minimal syntax change
**Cons:** New keyword

### Option B: `.new()` Static Method (Consistent with List/Map)
```cot
// Matches existing List.new(), Map.new() pattern
var p = Point.new(.x = 10, .y = 20)
// or with braces:
var p = Point.new{ .x = 10, .y = 20 }
```

**Pros:** Consistent with built-in types
**Cons:** Every struct needs implicit `.new()`, different from struct literal syntax

### Option C: `&` Prefix (Minimal)
```cot
var p = &Point{ .x = 10, .y = 20 }  // Returns *Point
```

**Pros:** Minimal syntax, pointer is explicit in syntax
**Cons:** `&` typically means "address of existing value", could confuse

### Option D: `box` Keyword (Rust-inspired)
```cot
var p = box Point{ .x = 10, .y = 20 }
```

**Pros:** Short, distinct from struct literal
**Cons:** Less familiar than `new`

## Recommendation: Option A (`new` keyword)

- Most familiar to developers from other languages
- Clear semantic: `new` = heap allocation
- Minimal syntax: just prefix existing struct literal
- Easy to teach: "add `new` to put it on the heap"

## Unified `new` Syntax for All Heap Types

For consistency, `new` should work for structs, List, and Map:

```cot
// Structs
var point = new Point{ .x = 10, .y = 20 }

// List (replaces List.new())
var list = new List<i64>                    // Empty list
var list = new List<i64>{ 1, 2, 3 }         // With initial values

// Map (replaces Map.new())
var map = new Map<string, i64>              // Empty map
var map = new Map<string, i64>{ "a": 1 }    // With initial values
```

### Implementation Notes

- `new List<T>` and `new Map<K,V>` use existing `list_new` (0xED) and `map_new` (0xD5) opcodes
- Brace initialization emits push/set operations after allocation
- Parser needs to handle `new Type` (no braces) for empty collections
- Parser needs to handle `new Type{ ... }` for initialized collections

## Implementation Plan

### Phase 1: Lexer (Zig Runtime)
**File:** `src/lexer/token.zig`
```zig
// Add to keyword list
.kw_new => "new",
```

**File:** `src/lexer/lexer.zig`
- Add `new` to keyword recognition

**Estimated effort:** 30 minutes

### Phase 2: Parser
**File:** `src/parser/parser.zig`

Add new expression parsing:
```zig
fn parseNewExpr(self: *Parser) !NodeIdx {
    _ = try self.expect(.kw_new);  // consume 'new'
    const type_name = try self.expect(.identifier);
    const init = try self.parseStructInit();
    return self.addNode(.new_expr, .{ .type = type_name, .init = init });
}
```

Integrate into `parsePrimaryExpr()` or `parseUnaryExpr()`.

**Estimated effort:** 1-2 hours

### Phase 3: AST Node
**File:** `src/ast/node_store.zig`

```zig
pub const Tag = enum {
    // ... existing tags ...
    new_expr,  // Heap allocation expression
};

// NewExpr data
pub const NewExpr = struct {
    type_id: StringIdx,      // struct type name
    field_inits: NodeRange,  // field initializations
};
```

**Estimated effort:** 30 minutes

### Phase 4: Type Checking
**File:** `src/compiler/type_checker.zig`

- Verify target is a struct type
- Validate all required fields are initialized
- Check field types match
- Result type is `*T` (pointer to struct)

```zig
fn checkNewExpr(self: *TypeChecker, node: NodeIdx) !TypeIdx {
    const struct_type = try self.resolveType(node.type_name);
    if (!struct_type.isStruct()) {
        return self.err("'new' requires a struct type");
    }
    try self.checkFieldInits(struct_type, node.field_inits);
    return self.makePointerType(struct_type);  // *T
}
```

**Estimated effort:** 2-3 hours

### Phase 5: IR Lowering
**File:** `src/ir/lower.zig` or `src/ir/lower_expr.zig`

Lower `new` expression to:
1. Allocate StructBox with ARC header
2. Initialize each field
3. Return pointer value

```zig
fn lowerNewExpr(self: *Lowerer, node: NodeIdx) !IrIdx {
    const struct_type = self.getType(node);
    const alloc = try self.emit(.struct_alloc, struct_type);
    for (node.field_inits) |init| {
        try self.emit(.struct_set_field, .{ alloc, init.field, init.value });
    }
    return alloc;
}
```

**Estimated effort:** 2-3 hours

### Phase 6: Bytecode Emission
**File:** `src/ir/emit_bytecode.zig`

Option A: Use existing `new_record` opcode (0x80)
Option B: Add new `struct_new` opcode for efficiency

```zig
fn emitNewExpr(self: *Emitter, ir: IrIdx) !void {
    // Emit: new_record rd, struct_type_idx
    try self.emitOp(.new_record);
    try self.emitReg(dest_reg);
    try self.emitU16(struct_type_idx);

    // Emit field initializations
    for (fields) |field| {
        try self.emitOp(.struct_set);
        // ...
    }
}
```

**Estimated effort:** 2-3 hours

### Phase 7: VM Handler (if new opcode needed)
**File:** `src/runtime/bytecode/vm_opcodes.zig`

If using existing `new_record`, verify it handles user structs correctly.
If adding new opcode, implement handler.

**Estimated effort:** 1-2 hours

### Phase 8: Testing
1. Unit tests for parser
2. Type checking tests (valid/invalid cases)
3. Runtime tests with GPA (memory leak detection)
4. Integration tests with ARC (verify cleanup)

**Estimated effort:** 2-3 hours

### Phase 9: Rust Runtime (cot-rs)
**CRITICAL:** Any changes to the Zig runtime must be mirrored in the Rust runtime.

**Files to update:**
- `cot-rs/src/lexer/` - Add `new` keyword token
- `cot-rs/src/parser/` - Parse new expressions
- `cot-rs/src/vm/` - Handle struct allocation opcode
- `cot-rs/src/arc.rs` - Verify ARC integration

**Estimated effort:** 3-4 hours (parallel Zig implementation)

## Total Estimated Effort

| Phase | Time |
|-------|------|
| Lexer (Zig) | 30 min |
| Parser (Zig) | 1-2 hours |
| AST Node | 30 min |
| Type Checking | 2-3 hours |
| IR Lowering | 2-3 hours |
| Bytecode | 2-3 hours |
| VM Handler (Zig) | 1-2 hours |
| Rust Runtime | 3-4 hours |
| Testing | 2-3 hours |
| **Total** | **15-21 hours** |

## Impact on Self-Hosted Compiler

Once `new` is implemented, the self-hosted compiler AST can use:
```cot
// Instead of index-based:
e.left_idx = allocExprIdx(left)

// Use pointer-based:
e.left = new Expr{ ... }
```

This enables cleaner, more intuitive AST code.

## Verification Checklist

- [ ] `new Point{ .x = 1, .y = 2 }` parses correctly
- [ ] Type checker validates struct type and fields
- [ ] Result type is `*Point` (pointer)
- [ ] ARC manages lifetime (refcount starts at 1)
- [ ] Memory freed when refcount reaches 0
- [ ] No memory leaks (GPA clean)
- [ ] Weak references work with new'd structs
- [ ] Cycle collector handles circular new'd structs

## Open Questions

1. **Syntax for arrays?**
   ```cot
   var arr = new [10]i64{}  // Heap-allocated array?
   ```

2. **Default field values?**
   ```cot
   var p = new Point{}  // Use defaults for x, y?
   ```

3. **Generic structs?**
   ```cot
   var b = new Box<i64>{ .value = 42 }
   ```

4. **Should `new` work with primitives?**
   ```cot
   var x = new i64(42)  // Boxed integer? Probably not needed.
   ```
