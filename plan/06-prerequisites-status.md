# Prerequisites Status Report

**Date:** 2026-01-06
**Phase:** 0 - Prerequisites Verification (COMPLETE)

## Summary

All critical language features required for the self-hosted compiler have been verified as working:

✅ **All P0 blockers fixed:**
- Character/substring access via slice syntax
- Array indexing
- Enum IR lowering
- Map.has() and Map.delete()

✅ **All P1 features working:**
- impl block method dispatch
- switch statement with enums
- Self-referential structs

**Status: READY TO PROCEED TO PHASE 1**

---

## Working Features ✓

| Feature | Status | Notes |
|---------|--------|-------|
| `len(str)` | ✓ Works | Built-in with dedicated opcode |
| String comparison `==`, `!=` | ✓ Works | |
| String concatenation `+` | ✓ Works | |
| Struct definition | ✓ Works | `struct Point { x: i64, y: i64 }` |
| Struct initialization | ✓ Works | `Point{ .x = 10, .y = 20 }` |
| Struct field access | ✓ Works | `p.x`, `p.y` |
| Struct field modification | ✓ Works | `p.x = 20` |
| Nested struct access | ✓ Works | `r.origin.x` |
| Function returning struct | ✓ Works | |
| `for-in` range iteration | ✓ Works | `for i in 0..5 { }` |
| `Map<K, V>` creation | ✓ Works | `Map.new()` |
| `Map.set()` | ✓ Works | |
| `Map.get()` | ✓ Works | |
| `Map.len()` | ✓ Works | |
| `char(code)` | ✓ Works | ASCII code to character |
| `upcase(str)` / `locase(str)` | ✓ Works | Case conversion |
| `instr(haystack, needle)` | ✓ Works | Find substring position |
| `s[start..end]` slice syntax | ✓ Works | 0-based, end exclusive. `s[0..5]` gets chars 0-4 |
| `impl` blocks | ✓ Works | Methods with `self` parameter work |
| `Map.has()` | ✓ Works | Requires type inference (no explicit annotation) |
| `Map.delete()` | ✓ Works | Requires type inference (no explicit annotation) |
| Enum definitions | ✓ Works | `enum TokenType { Ident, Number }` |
| `switch` statement | ✓ Works | `switch (val) { Pat => expr, }` |
| Self-referential structs | ✓ Works | `struct Node { next: ?*Node }` |

---

## Critical Gaps (P0 - Blocking)

### 1. ~~Character/Substring Access~~ FIXED
**Status:** ✓ IMPLEMENTED

Modern slice syntax `s[start..end]` now works in .cot files:
- 0-based indexing (modern Cot)
- End index is exclusive (like Go, Python, Rust)
- Example: `"Hello"[0..2]` returns `"He"`

### 2. ~~Array Indexing Bug~~ FIXED
**Status:** ✓ FIXED

```cot
const arr = [1, 2, 3]
const x = arr[0]  // Now works correctly
```

**Fix:** Modified `lowerLetDecl` to handle array pointers like struct pointers, avoiding double-pointer wrapping.

### 3. ~~Enum IR Lowering Panic~~ FIXED
**Status:** ✓ FIXED

```cot
enum TokenType {
    Identifier,
    Number,
}
```

**Fix:** The DBL format detection heuristic was incorrectly triggering when there was more data in extra_data after the enum. Simplified to always use Cot format (auto-increment values from 0).

### 4. ~~Map.has() and Map.delete() Invalid Opcode~~ FIXED
**Status:** ✓ METHODS WORK (type annotation issue separate)

```cot
var m = Map.new()  // Use type inference instead of annotation
m.set("key", 42)
m.has("key")     // Works!
m.delete("key")  // Works!
```

**Note:** The methods work when Map is created without explicit type annotation. The `Map<string, i64>` type annotation has a separate issue with type checking.

---

## Medium Gaps (P1 - Important)

### 5. ~~impl Block Method Dispatch~~ FIXED
**Status:** ✓ FIXED

```cot
struct Calculator { result: i64 }

impl Calculator {
    fn get(self: Calculator) i64 {
        return self.result
    }
    fn add(self: Calculator, n: i64) i64 {
        return self.result + n
    }
}

var calc: Calculator = Calculator{ .result = 10 }
calc.get()       // Works! Returns 10
calc.add(5)      // Works! Returns 15
```

**Fix:** Modified `lowerMethodCall` in `lower_expr.zig` to construct qualified method names (e.g., `Calculator.get`) for struct method calls, matching how impl methods are registered.

### 6. ~~switch Statement~~ FIXED
**Status:** ✓ WORKS

Cot uses `switch` (not `match`) with Zig-style syntax:

```cot
enum Color { Red, Green, Blue }

switch (c) {
    Color.Red => println("red"),
    Color.Green => println("green"),
    Color.Blue => println("blue"),
}
```

---

## Recommendations

### Immediate Actions (Block Self-Hosting)

1. **Fix array indexing bug** - Enable `arr[i]` to work with array literals
2. **Fix enum IR lowering** - Enable TokenType enum definition
3. **Implement substring access** - Add `s[i]` or substring function for .cot files
4. **Fix Map.has() and Map.delete()** - Fix invalid opcode errors

### Secondary Actions

5. ~~Complete impl block method dispatch~~ ✓ DONE
6. ~~Test switch statement with working enums~~ ✓ DONE
7. ~~Test self-referential structs (`Node { left: ?*Node }`)~~ ✓ DONE

---

## Test Files Created

- `tests/prereq_basic.cot` - Basic tests (partial pass)
- `tests/prereq_maps.cot` - Map tests (partial pass)
- `tests/prereq_noarray.cot` - Tests without arrays (all pass)

---

## Verified Working Syntax Examples

### Struct with Functions
```cot
struct Token {
    text: string,
    line: i64,
    column: i64,
}

fn make_token(txt: string, ln: i64, col: i64) Token {
    return Token{ .text = txt, .line = ln, .column = col }
}
```

### Map as Symbol Table
```cot
var symbols = Map.new()        // Type inference required
symbols.set("x", 10)
const val = symbols.get("x")   // Works
const exists = symbols.has("x") // Works!
symbols.delete("x")             // Works!
```

### For-In Iteration
```cot
for i in 0..5 {
    // i goes 0, 1, 2, 3, 4
}
```

### Impl Block Methods
```cot
struct Counter {
    value: i64,
}

impl Counter {
    fn get(self: Counter) i64 {
        return self.value
    }
    fn add(self: Counter, n: i64) i64 {
        return self.value + n
    }
}

var c: Counter = Counter{ .value = 10 }
println(string(c.get()))     // Prints 10
println(string(c.add(5)))    // Prints 15
```
