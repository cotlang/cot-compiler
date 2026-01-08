# Feature Parity Plan: cot-compiler vs SYNTAX.md

**Created:** 2026-01-08
**Purpose:** Track language features from `~/cotlang/SYNTAX.md` that require logic changes in cot-compiler.

The self-hosted compiler has all phases code-complete (lexer, parser, type checker, IR, bytecode). However, several language features have placeholder or incomplete implementations. This document tracks what needs to change to achieve full Cot language support.

---

## Status Legend
- [ ] Not started
- [~] In progress
- [x] Complete

---

## P0: Critical Features (Block Self-Hosting)

### 1. Sum Type Payloads (Enum Variants with Data)

**Syntax from SYNTAX.md:**
```cot
enum Option {
    Some(i64)      // Tuple-style payload
    None
}

enum Result {
    Ok { value: i64 }   // Struct-style payload
    Err { msg: string }
}

let x = Option.Some(42)
switch (x) {
    Option.Some(val) => println(val)  // Pattern binding
    Option.None => println("none")
}
```

**Current State:** Parser and type checker treat all enum variants as simple discriminants (no payloads).

**Files to Change:**

| File | Location | Current | Required |
|------|----------|---------|----------|
| `parser.cot` | `parseEnumDecl` lines 1963-2009 | Parses variant name only | Parse `(T)` tuple payload or `{ field: T }` struct payload |
| `parser.cot` | `parseEnumVariantExpr` | Creates EnumVariant without args | Parse and store payload arguments |
| `ast.cot` | `EnumVariant` struct | No payload_types field | Add `payload_types: []TypeRef` |
| `type_checker.cot` | `collectEnumDecl` lines 431-466 | Sets `payload_type_id = -1` | Store variant payload type IDs |
| `type_checker.cot` | `checkSwitchStmt` | No pattern binding | Extract and bind payload variables in scope |
| `lower.cot` | `lowerEnumVariantExpr` | Simple integer tag | Emit `variant_construct` with payload values |
| `lower.cot` | `lowerSwitchStmt` | Compare tags only | Emit `variant_get_tag` + `variant_get_payload` |

**Test Files:**
- `/tmp/test_multi.cot` - Multi-payload enum (Move(i64, i64), Write(string))
- `/tmp/test_result.cot` - Result enum with payloads

---

### 2. Defer Statement (LIFO Execution at Scope Exit)

**Syntax from SYNTAX.md:**
```cot
fn process() {
    let f = open("file.txt")
    defer f.close()    // Executes when function returns

    if (error) {
        return         // defer still runs
    }
    // defer runs here too
}
```

**Current State:** `lowerDeferStmt` executes the deferred expression immediately.

**Files to Change:**

| File | Location | Current | Required |
|------|----------|---------|----------|
| `lower.cot` | `lowerDeferStmt` lines 1463-1470 | `lowerExpr(defer_expr)` executes immediately | Push to defer stack, emit at scope exits |
| `lower.cot` | Scope struct | No defer tracking | Add `defer_stack: List<Expr>` |
| `lower.cot` | `lowerReturnStmt` | No defer handling | Pop and emit deferred expressions in LIFO order |
| `lower.cot` | `exitScope` | No defer handling | Emit deferred expressions when exiting scope |
| `lower.cot` | `lowerBlock` | No defer handling | Handle defers at block end |

**Implementation Notes:**
- Defers must execute in reverse order (LIFO)
- Must execute on all exit paths: return, break, continue, throw, normal exit
- Each scope level has its own defer stack

---

### 3. Switch Expression (Expression Form)

**Syntax from SYNTAX.md:**
```cot
let msg = switch (code) {
    200 => "OK"
    404 => "Not Found"
    _ => "Unknown"
}
```

**Current State:** `lowerSwitchExpr` creates basic blocks but doesn't process switch arms.

**Files to Change:**

| File | Location | Current | Required |
|------|----------|---------|----------|
| `lower.cot` | `lowerSwitchExpr` lines 722-753 | Creates exit block, jumps to it | Lower each arm, collect result values, create phi node |
| `ir.cot` | - | May need phi instruction | Add `IRPhi` for merging values from multiple paths |

**Implementation Notes:**
- Each arm produces a value
- All arms must produce same type (or compatible types)
- Need phi node or result register to merge values

---

## P1: Important Features (Full Language Support)

### 4. Lambda/Closure Expressions

**Syntax from SYNTAX.md:**
```cot
let add = |a, b| a + b
let double = |x| { return x * 2 }
let captured = |x| x + outer_var  // Closure captures outer_var
```

**Current State:** `lowerLambdaExpr` returns placeholder value 0.

**Files to Change:**

| File | Location | Current | Required |
|------|----------|---------|----------|
| `lower.cot` | `lowerLambdaExpr` lines 755-768 | Returns `makeIntConst(0)` | Create closure object with captured env |
| `lower.cot` | Capture analysis | Not implemented | Identify free variables in lambda body |
| `ir.cot` | Closure IR ops | Has `IROp.Closure` stub | Implement closure construction/call |
| `emit.cot` | Closure emission | Has opcodes defined | Wire up make_closure, call_closure |

**Implementation Notes:**
- Need to analyze lambda body for free variables
- Create environment struct capturing those variables
- Closure = (function_ptr, environment_ptr)

---

### 5. Method Call Type Resolution

**Syntax from SYNTAX.md:**
```cot
impl Point {
    fn distance(self) f64 {
        return sqrt(self.x*self.x + self.y*self.y)
    }
}

let p = Point { x: 3.0, y: 4.0 }
let d = p.distance()  // Should resolve to f64
```

**Current State:** `checkMethodCallExpr` returns i64 as default instead of looking up method signature.

**Files to Change:**

| File | Location | Current | Required |
|------|----------|---------|----------|
| `type_checker.cot` | `checkMethodCallExpr` lines 1506-1530 | Returns `i64_type_id` | Look up impl block, find method, return actual return type |
| `type_checker.cot` | Method registry | Partially implemented | Ensure all impl methods are registered with signatures |

---

### 6. Try/Catch Error Propagation ✅ COMPLETE (2026-01-08)

**Syntax from SYNTAX.md:**
```cot
fn risky() !i64 {
    throw "something went wrong"
}

fn caller() {
    try {
        let x = risky()
    } catch (e) {
        println("Error: " + e)
    }
}
```

**Implementation Complete:**

| File | Changes |
|------|---------|
| `ir.cot` | Added `IROp.SetHandler` and `IROp.ClearHandler` |
| `emit.cot` | Added `IR_SET_HANDLER`, `IR_CLEAR_HANDLER`, `IR_ERR_THROW` constants; `emitSetErrorHandler`, `emitClearErrorHandler`, `emitThrow` functions |
| `lower.cot` | Updated `lowerTryStmt` to emit `SetHandler` before try body, `ClearHandler` after |
| Zig VM | Implemented `ErrorHandlerStack` for nested try/catch; fixed `clear_error_handler` IP increment bug |
| Rust VM | Added `ErrorHandler` struct and `error_handlers: Vec<ErrorHandler>` for nested support |

---

### 7. Range Type and Iteration

**Syntax from SYNTAX.md:**
```cot
for (i in 0..10) {
    println(i)
}

let r = 0..=5  // Inclusive range
```

**Current State:** No Range type in types.cot.

**Files to Change:**

| File | Location | Current | Required |
|------|----------|---------|----------|
| `types.cot` | TypeKind enum | No `Range` variant | Add `TypeKind.Range` |
| `parser.cot` | `parseBinaryExpr` | No `..` / `..=` operators | Parse range operators, create range expression |
| `type_checker.cot` | Range checking | Not implemented | Type check range bounds (must be integers) |
| `lower.cot` | Range lowering | Not implemented | Lower to start/end/inclusive struct or iterator |

---

## P2: Polish Features (Nice to Have)

### 8. String Interpolation

**Syntax from SYNTAX.md:**
```cot
let name = "world"
println("Hello, {name}!")
println("2 + 2 = {2 + 2}")
```

**Current State:** Lexer has interpolation tokens. Parser/lower may need work.

---

### 9. Comptime Evaluation

**Syntax from SYNTAX.md:**
```cot
comptime {
    let x = 1 + 2  // Evaluated at compile time
}

comptime if (DEBUG) {
    // Conditionally compiled
}
```

**Current State:** Parser handles `parseComptimeStmt`. Lower may need implementation.

---

## Task Checklist

### Immediate (P0)

- [x] **Sum Types Phase 1: Parser** ✅ (2026-01-08)
  - [x] Modify `EnumVariant` in ast.cot to store payload types
  - [x] Modify `parseEnumDecl` to parse `(T)` and `{ field: T }` payloads
  - [x] Modify `parseEnumVariantExpr` to parse payload arguments
  - [x] Test: Parse `/tmp/test_multi.cot` and `/tmp/test_result.cot`

- [x] **Sum Types Phase 2: Type Checker** ✅ (2026-01-08)
  - [x] Modify `collectEnumDecl` to register payload type IDs
  - [x] Modify `checkEnumVariantCall` to type-check payload arguments
  - [x] Modify `bindPatternVariables` to bind payload variables in case patterns
  - [x] Test: Type checker compiles successfully

- [x] **Sum Types Phase 3: IR Lowering** ✅ (2026-01-08)
  - [x] Modify `lowerEnumVariantExpr` to emit `variant_construct`
  - [x] Modify switch lowering to emit `variant_get_tag` and `variant_get_payload`
  - [x] Test: Lower and execute test files

- [x] **Defer Phase 1: Scope Tracking** ✅ (2026-01-08)
  - [x] Add defer stack to Scope struct in lower.cot
  - [x] Modify `lowerDeferStmt` to push to defer stack (not execute)
  - [x] Test: Defer is not immediately executed

- [x] **Defer Phase 2: Exit Handling** ✅ (2026-01-08)
  - [x] Modify `lowerReturnStmt` to pop and emit defers
  - [x] Modify `exitScope` to emit pending defers
  - [x] Handle break/continue with defer
  - [x] Test: Defers execute in LIFO order at scope exit

### Short Term (P1)

- [x] **Switch Expression** ✅ (2026-01-08)
  - [x] Implement arm processing in `lowerSwitchExpr`
  - [x] Store arm values to result allocation
  - [x] Test: Switch expressions produce values

- [x] **Method Resolution** ✅ (2026-01-08)
  - [x] Add `method_returns` map to TypeChecker
  - [x] Register method return types in `checkImplDecl`
  - [x] Fix `checkMethodCallExpr` to look up actual method signature
  - [x] Test: Method calls have correct return types

- [x] **Lambda/Closure** ✅ (2026-01-08)
  - [x] Implement free variable analysis (`collectFreeVariables` in lower.cot)
  - [x] Generate closure construction IR (`lowerLambdaExpr` with `MakeClosure` op)
  - [x] Wire up closure opcodes in emit.cot
  - [x] Test: Simple closures capture variables (`double(5)=10`, `triple(7)=21`)

- [x] **Try/Catch** ✅ (2026-01-08)
  - [x] Add IROp.SetHandler and IROp.ClearHandler to ir.cot
  - [x] Add error handler bytecode emission to emit.cot
  - [x] Update lowerTryStmt to emit SetHandler before try body, ClearHandler after
  - [x] Implement nested handler stack in Zig VM (vm.zig, vm_opcodes.zig)
  - [x] Implement nested handler stack in Rust VM (cot-rs/src/vm/)
  - [x] Test: Exceptions propagate to catch blocks (nested try/catch works)

### Medium Term (P2)

- [x] **Range Type** ✅ (2026-01-08)
  - [x] Add Range type to types.cot (TypeTag.Range, range_inclusive field)
  - [x] Parse `..` and `..=` range operators (parser.cot lines 452-462)
  - [x] Lower range iteration in for loops (lowerForRangeStmt)
  - [x] Test: for-in loops with ranges work

- [x] **String Interpolation** ✅ (2026-01-08)
  - [x] Verify interpolation lowering works
  - [x] Test: Interpolated strings compile and run (`"Hello, ${name}!"` outputs correctly)

- [x] **Comptime** ✅ (2026-01-08)
  - [x] Verify comptime blocks are handled in functions
  - [x] Add top-level comptime support to Zig parser (parser.zig:206)
  - [x] Test: Comptime blocks work at top level and inside functions

---

## Verification

After implementing each feature, verify with:

```bash
cd ~/cotlang/cot-compiler
cot compile src/parser.cot -o /tmp/parser.cbo  # Must compile
cot run /tmp/parser.cbo -- test_file.cot        # Must parse correctly
```

End-to-end bootstrap test (after all P0 complete):
```bash
# Stage 1: Zig compiler compiles cot-compiler
cot compile src/driver.cot -o /tmp/cot-stage1.cbo

# Stage 2: cot-stage1 compiles itself
cot run /tmp/cot-stage1.cbo -- compile src/driver.cot -o /tmp/cot-stage2.cbo

# Verify: identical output
diff /tmp/cot-stage1.cbo /tmp/cot-stage2.cbo
```

---

## Cross-Reference

- **Sum types in Zig compiler:** `src/ir/lower.zig` (variant_construct, variant_get_tag, variant_get_payload)
- **Defer in Zig compiler:** `src/ir/lower_stmt.zig` (defer stack tracking)
- **Language spec:** `~/cotlang/SYNTAX.md`
- **Self-hosted compiler source:** `~/cotlang/cot-compiler/src/`
