# Gap Analysis: Zig Compiler vs Cot Capabilities

## Executive Summary

The Zig compiler uses advanced features that Cot must either:
1. **Implement** - Add the feature to Cot
2. **Simplify** - Use a simpler Cot equivalent
3. **Skip** - Not needed for a working compiler

---

## CRITICAL GAPS (Must Fix)

### 1. Enum with Associated Data (Tagged Unions)

**Zig Usage:**
```zig
pub const Type = union(enum) {
    void,
    bool,
    i32,
    ptr: *const Type,
    array: struct { element: *const Type, length: u32 },
    @"struct": *const StructType,
};
```

**Cot Current:** Basic enums only (no associated data)
```cot
enum Color { .red, .green, .blue }
```

**Cot Needed:** Tagged unions with payloads
```cot
enum Type {
    Void,
    Bool,
    I32,
    Ptr(Type),           // payload: another Type
    Array(Type, i32),    // payload: element type + length
    Struct(StructType),  // payload: struct definition
}
```

**Impact:** HIGH - The entire type system representation depends on this.

**Workaround:** Use struct with tag field + optional fields
```cot
struct Type {
    tag: TypeTag,
    ptr_inner: ?Type,
    array_element: ?Type,
    array_length: i32,
    struct_def: ?StructType,
}
```

---

### 2. Recursive/Self-Referential Types

**Zig Usage:**
```zig
ptr: *const Type,  // Type contains pointer to Type
```

**Cot Current:** No self-referential structs tested

**Cot Needed:**
```cot
struct Type {
    inner: ?*Type,  // pointer to another Type
}
```

**Impact:** HIGH - AST nodes reference other AST nodes.

**Status:** May already work - needs testing.

---

### 3. Result/Error Types

**Zig Usage:**
```zig
fn parse() ParseError!Ast { ... }
const result = try parse();
```

**Cot Current:** Has try/catch but unclear if `T!E` union works

**Cot Needed:**
```cot
fn parse() Result<Ast, ParseError> { ... }
// or
fn parse() ?Ast { ... }  // simpler: null on error
```

**Impact:** MEDIUM - Error propagation throughout compiler.

**Workaround:** Use `?T` (optional) + separate error reporting.

---

### 4. Generic Containers with Methods

**Zig Usage:**
```zig
var map = std.StringHashMap(Value).init(allocator);
try map.put(key, value);
const val = map.get(key);
```

**Cot Current:** `Map<K, V>` exists but method syntax unclear

**Cot Needed:**
```cot
var map = Map<string, Value>.new()
map.put(key, value)
let val = map.get(key)
```

**Impact:** HIGH - Maps used everywhere for symbol tables.

**Status:** Likely works - needs verification.

---

### 5. Array/List with Dynamic Sizing

**Zig Usage:**
```zig
var list = std.ArrayList(Token).init(allocator);
try list.append(token);
const slice = list.toOwnedSlice();
```

**Cot Current:** Fixed arrays `[N]T`, unclear on dynamic lists

**Cot Needed:**
```cot
var tokens: []Token = []
tokens.push(token)
// or
var tokens = List<Token>.new()
tokens.append(token)
```

**Impact:** HIGH - Token list, AST nodes, etc.

**Status:** Needs implementation or verification.

---

### 6. String Builder / Efficient Concatenation

**Zig Usage:**
```zig
var buf: [1024]u8 = undefined;
const result = std.fmt.bufPrint(&buf, "{s}_{d}", .{name, id});
```

**Cot Current:** String concatenation with `+`, interpolation with `${}`

**Cot Needed:** Efficient building for large strings
```cot
var sb = StringBuilder.new()
sb.append("hello")
sb.append(name)
let result = sb.toString()
```

**Impact:** MEDIUM - Error messages, code generation.

**Workaround:** Use string interpolation (may be slow for large strings).

---

### 7. File Reading to String

**Zig Usage:**
```zig
const content = try file.readToEndAlloc(allocator, max_size);
```

**Cot Current:** `read_file(path)` exists

**Status:** ✓ Already implemented - just verify it works.

---

### 8. Character-Level String Access

**Zig Usage:**
```zig
const ch = source[i];
if (ch == '"') { ... }
```

**Cot Current:** `substring(str, i, 1)` for single char?

**Cot Needed:**
```cot
let ch = str[i]      // or str.charAt(i)
if ch == '"' { ... }
```

**Impact:** HIGH - Lexer is entirely character-based.

**Status:** Needs verification - may need `char_at(str, i)` native.

---

### 9. Switch/Match on Enums

**Zig Usage:**
```zig
switch (token.type) {
    .identifier => { ... },
    .number => { ... },
    else => { ... },
}
```

**Cot Current:** `match` exists but unclear on enum variants

**Cot Needed:**
```cot
match token.type {
    TokenType.Identifier => { ... }
    TokenType.Number => { ... }
    else => { ... }
}
```

**Impact:** HIGH - Used throughout compiler.

**Status:** Likely works - needs testing.

---

## MEDIUM GAPS (Should Fix)

### 10. Multiple Return Values / Destructuring

**Zig Usage:**
```zig
const line, const col = getPosition();
```

**Cot Needed:**
```cot
let (line, col) = getPosition()
```

**Workaround:** Return struct `Position { line, col }`.

---

### 11. Slice/Range Operations

**Zig Usage:**
```zig
const sub = source[start..end];
```

**Cot Needed:**
```cot
let sub = source[start:end]  // or substring(source, start, end - start)
```

**Status:** `substring()` exists - sufficient.

---

### 12. Const vs Let Semantics

**Zig Usage:**
```zig
const x = 5;  // immutable
var y = 5;    // mutable
```

**Cot Current:** Has `let` and `const`

**Status:** ✓ Already implemented.

---

### 13. Optional Chaining

**Zig Usage:**
```zig
if (value) |v| { ... }  // unwrap optional
```

**Cot Current:** `?.` operator exists

**Cot Needed:**
```cot
if let v = value {
    // v is unwrapped
}
```

**Status:** Needs verification.

---

## LOW GAPS (Can Work Around)

### 14. defer/errdefer

**Zig Usage:**
```zig
defer list.deinit();
errdefer allocated.free();
```

**Cot Workaround:** Explicit cleanup or rely on ARC
```cot
// ARC handles most cleanup automatically
// For explicit: use try/finally pattern
try {
    // ...
} catch {
    cleanup()
    throw
}
cleanup()
```

---

### 15. Comptime Evaluation

**Zig Usage:**
```zig
comptime {
    const x = compute();
}
```

**Cot Workaround:** Runtime constants or skip
```cot
const X = 42  // evaluated at parse time if literal
```

---

### 16. Packed Structs / Bit Fields

**Zig Usage:**
```zig
pub const SourceLoc = packed struct {
    line: u24,
    column: u8,
};
```

**Cot Workaround:** Regular structs (use more memory)
```cot
struct SourceLoc {
    line: i32,
    column: i32,
}
```

---

### 17. Custom Hash Functions

**Zig Usage:**
```zig
std.HashMapUnmanaged(K, V, CustomContext, load_factor)
```

**Cot Workaround:** Use string keys, convert complex keys to strings
```cot
// Instead of: map[ImplKey{trait: "Foo", type: "Bar"}]
// Use: map["Foo:Bar"]
```

---

### 18. Arena Allocators

**Zig Usage:**
```zig
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();
```

**Cot Workaround:** ARC handles memory automatically.

---

## FEATURE COMPARISON MATRIX

| Feature | Zig Compiler Uses | Cot Has | Gap | Priority |
|---------|-------------------|---------|-----|----------|
| Tagged unions | Yes (heavily) | No | HIGH | P0 |
| Self-referential types | Yes | Unclear | HIGH | P0 |
| HashMap<K,V> | Yes (15+ maps) | Yes | Verify | P0 |
| Dynamic arrays | Yes | Unclear | HIGH | P0 |
| Character indexing | Yes | Unclear | HIGH | P0 |
| Match on enums | Yes | Yes | Verify | P1 |
| Error result types | Yes | Partial | MEDIUM | P1 |
| String builder | Yes | No | MEDIUM | P1 |
| Optional unwrap | Yes | Yes | Verify | P1 |
| Tuple returns | Yes | Unclear | LOW | P2 |
| defer | Yes (200+) | No | LOW | P2 |
| Packed structs | Yes | No | Skip | - |
| Comptime | Yes | No | Skip | - |
| Arena allocators | Yes | No | Skip | - |

---

## RECOMMENDED APPROACH

### Phase 0: Verify & Fix Prerequisites (3-5 days)

1. **Test self-referential structs** - Critical for AST
2. **Test Map<string, T> methods** - Critical for symbol tables
3. **Implement/verify dynamic array** - Critical for token list
4. **Implement char_at(str, i)** - Critical for lexer
5. **Test match on enum values** - Critical for dispatch

### Phase 1: Lexer (2-3 days)

Use only verified features:
- Strings, character access
- Basic structs (Token, SourceLoc)
- Simple enum for TokenType
- Dynamic array for token list

### Phase 2+: Build Up

Add features as needed, always with fallback:
- Tagged union → Struct with tag + nullable fields
- defer → Explicit cleanup calls
- Result<T,E> → Optional + error field
