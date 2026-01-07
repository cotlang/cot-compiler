# Phase 6: Bootstrap Execution Plan

**Updated: 2026-01-07**

## Overview

Bootstrap is the ultimate test of compiler correctness. We attempt to compile the Cot compiler with itself. This WILL uncover bugs - that's the point.

## Current State

| File | Lines | Compiles | Status |
|------|-------|----------|--------|
| token.cot | 349 | ✅ | Complete |
| lexer.cot | 652 | ✅ | Complete |
| ast.cot | 355 | ✅ | Complete |
| parser.cot | 2,242 | ✅ | Complete |
| types.cot | 892 | ✅ | Complete |
| type_checker.cot | 1,883 | ✅ | Complete |
| ir.cot | 592 | ✅ | Complete |
| lower.cot | 1,700 | ✅ | Complete |
| opcodes.cot | 453 | ✅ | Complete |
| emit.cot | 1,684 | ✅ | Complete |
| **Total** | **10,802** | ✅ | **Code Complete** |

**Note:** "Code Complete" means all handlers exist. Bootstrap testing will reveal bugs.

---

## Stage 1: Integration Testing (Verify Pipeline)

### 1.1 Test Each Component Individually

**Test 1.1.1: Lexer**
- Input: Simple Cot source string
- Output: List of tokens
- Verify: Token types, values, positions correct

**Test 1.1.2: Parser**
- Input: Token stream
- Output: AST
- Verify: AST structure matches expected

**Test 1.1.3: Type Checker**
- Input: AST
- Output: Typed AST + errors
- Verify: Types resolved, errors caught

**Test 1.1.4: IR Lowering**
- Input: Typed AST
- Output: IR Module
- Verify: IR instructions correct

**Test 1.1.5: Bytecode Emission**
- Input: IR Module
- Output: .cbo bytecode
- Verify: Bytecode runs correctly

---

## Stage 2: End-to-End Testing (Simple Programs)

### 2.1 Trivial Programs
```cot
// test_trivial_1.cot - Return constant
fn main() i64 {
    return 42
}

// test_trivial_2.cot - Arithmetic
fn main() i64 {
    return 1 + 2 * 3
}

// test_trivial_3.cot - Variable
fn main() i64 {
    const x = 10
    return x
}
```

### 2.2 Control Flow Programs
```cot
// test_if.cot
fn main() i64 {
    const x = 5
    if (x > 3) {
        return 1
    } else {
        return 0
    }
}

// test_while.cot
fn main() i64 {
    var sum = 0
    var i = 0
    while (i < 10) {
        sum = sum + i
        i = i + 1
    }
    return sum
}
```

### 2.3 Function Programs
```cot
// test_fn.cot
fn add(a: i64, b: i64) i64 {
    return a + b
}

fn main() i64 {
    return add(3, 4)
}

// test_recursion.cot
fn fib(n: i64) i64 {
    if (n <= 1) {
        return n
    }
    return fib(n - 1) + fib(n - 2)
}

fn main() i64 {
    return fib(10)
}
```

### 2.4 Struct Programs
```cot
// test_struct.cot
struct Point {
    x: i64,
    y: i64,
}

fn main() i64 {
    const p = Point{ .x = 3, .y = 4 }
    return p.x + p.y
}
```

### 2.5 Enum Programs
```cot
// test_enum.cot
enum Color {
    Red,
    Green,
    Blue,
}

fn main() i64 {
    const c = Color.Green
    switch (c) {
        Color.Red => { return 0 }
        Color.Green => { return 1 }
        Color.Blue => { return 2 }
    }
}
```

---

## Stage 3: Compiler Module Compilation

### 3.1 Compilation Order (by dependency)

1. **token.cot** (no dependencies)
2. **lexer.cot** (depends on: token)
3. **ast.cot** (depends on: token)
4. **parser.cot** (depends on: token, ast)
5. **types.cot** (no dependencies)
6. **type_checker.cot** (depends on: types, ast, token)
7. **ir.cot** (no dependencies)
8. **lower.cot** (depends on: ir, ast, types, token)
9. **opcodes.cot** (no dependencies)
10. **emit.cot** (depends on: ir, opcodes)

### 3.2 For Each Module

```bash
# Step 1: Compile with Zig cot (reference)
cot compile src/token.cot -o /tmp/token_zig.cbo

# Step 2: Compile with Cot cot (bootstrap)
# This requires a main.cot driver that uses all modules
cot run bootstrap/compile.cbo src/token.cot -o /tmp/token_cot.cbo

# Step 3: Compare bytecode
cot validate /tmp/token_zig.cbo
cot validate /tmp/token_cot.cbo

# Step 4: Run both and compare output
cot run /tmp/token_zig.cbo
cot run /tmp/token_cot.cbo
```

### 3.3 Expected Issues

These are likely to fail and need debugging:
- [ ] Import resolution (modules need to find each other)
- [ ] String handling in lexer
- [ ] Large switch statements in parser
- [ ] Generic type instantiation in type_checker
- [ ] Complex control flow in lower.cot

### 3.4 Stage 3 Results (2026-01-07)

**All 10 modules compile successfully with the Zig cot compiler!**

| Module | Lines | Bytecode Size | Validation |
|--------|-------|---------------|------------|
| token.cot | 349 | 50KB | ✅ PASS |
| lexer.cot | 652 | 76KB | ✅ PASS |
| ast.cot | 355 | 54KB | ✅ PASS |
| parser.cot | 2,242 | 275KB | ✅ PASS |
| types.cot | 892 | 44KB | ✅ PASS |
| type_checker.cot | 1,883 | 170KB | ✅ PASS |
| ir.cot | 592 | 16KB | ✅ PASS |
| lower.cot | 1,700 | 208KB | ✅ PASS |
| opcodes.cot | 453 | 109KB | ✅ PASS |
| emit.cot | 1,684 | 76KB | ✅ PASS |
| **Total** | **10,802** | **1,078KB** | **100%** |

All modules:
- 0 compilation errors
- 0 validation errors
- 100% code coverage (all code reachable)

**Next:** Create bootstrap driver (Stage 4) to test the compiled modules.

---

## Stage 4: Create Bootstrap Driver

### 4.1 bootstrap/main.cot
```cot
// Main compiler driver
import "token"
import "lexer"
import "ast"
import "parser"
import "types"
import "type_checker"
import "ir"
import "lower"
import "opcodes"
import "emit"

fn main(args: []string) i64 {
    if (len(args) < 2) {
        print("Usage: cot-bootstrap <input.cot> [-o output.cbo]")
        return 1
    }

    const source = readFile(args[1])

    // Lex
    var lexer = newLexer(source)
    const tokens = lexerScanAll(lexer)

    // Parse
    var parser = newParser(tokens)
    const ast = parserParse(parser)

    // Type check
    var tc = newTypeChecker()
    tcCheck(tc, ast)
    if (tc.had_error) {
        return 1
    }

    // Lower to IR
    var lowerer = newLowerer(tc.reg)
    lowerModule(lowerer, ast)

    // Emit bytecode
    var emitter = newEmitter(lowerer.module)
    emitModule(emitter)

    // Write output
    const output_path = getOutputPath(args)
    writeFile(output_path, emitter.bytes)

    return 0
}
```

### 4.2 Missing Pieces to Implement

1. **File I/O**: `readFile()`, `writeFile()` - need native function bindings
2. **Lexer batch mode**: `lexerScanAll()` - scan all tokens at once
3. **Parser entry point**: `parserParse()` - parse entire file
4. **Command line parsing**: Handle `-o` flag

---

## Stage 5: Iterative Bug Fixing

### 5.1 Bug Tracking Template

For each bug found:
```markdown
## Bug #N: [Short Description]

**Stage:** [Stage where found]
**Module:** [Which .cot file]
**Symptom:** [What happened]
**Expected:** [What should happen]
**Root Cause:** [After investigation]
**Fix:** [What was changed]
**Verified:** [ ] Bug fixed, tests pass
```

### 5.2 Expected Bug Categories

1. **Lexer bugs**
   - Escape sequences in strings
   - Number literal edge cases
   - Comment handling

2. **Parser bugs**
   - Operator precedence
   - Expression vs statement ambiguity
   - Error recovery

3. **Type checker bugs**
   - Generic instantiation
   - Method resolution
   - Coercion rules

4. **Lowering bugs**
   - Control flow (break/continue targets)
   - Variable scoping
   - Struct field access

5. **Emission bugs**
   - Jump offset calculation
   - Constant pool indices
   - Register allocation

---

## Stage 6: Full Bootstrap Verification

### 6.1 Three-Stage Bootstrap

```
Stage A: Zig-cot compiles Cot-cot source → cot-bootstrap-a.cbo
Stage B: cot-bootstrap-a compiles Cot-cot source → cot-bootstrap-b.cbo
Stage C: cot-bootstrap-b compiles Cot-cot source → cot-bootstrap-c.cbo

Verify: cot-bootstrap-b.cbo == cot-bootstrap-c.cbo (byte-for-byte)
```

If Stage B output equals Stage C output, the compiler is self-consistent.

### 6.2 Success Criteria

- [ ] All 10 modules compile with Cot compiler
- [ ] Bootstrap driver compiles itself
- [ ] Three-stage bootstrap produces identical output
- [ ] All test programs produce correct results
- [ ] No memory leaks or runtime errors

---

## Realistic Expectations

| Stage | Description | Estimated Issues |
|-------|-------------|------------------|
| Stage 1 | Integration tests | 5-10 bugs |
| Stage 2 | Simple programs | 10-20 bugs |
| Stage 3 | Module compilation | 20-50 bugs |
| Stage 4 | Bootstrap driver | 5-10 bugs |
| Stage 5 | Bug fixing | Iterative |
| Stage 6 | Full verification | Final polish |

**"Code Complete" ≠ "Bug Free"**

The compiler code exists and compiles, but bootstrap testing will reveal:
- Logic errors in lowering
- Missing edge cases in type checking
- Incorrect bytecode emission
- Integration issues between modules

---

## Immediate Next Steps

1. [x] Create `tests/bootstrap/` directory
2. [x] Write Stage 2 test programs (trivial → complex)
3. [x] Run test programs with Zig cot compiler to verify they work
4. [ ] Create minimal test that exercises the full pipeline
5. [ ] Debug first failures

## Stage 2 Test Results (2026-01-07)

| Test | Expected | Actual | Status |
|------|----------|--------|--------|
| test_return.cot | 42 | 42 | ✅ PASS |
| test_arithmetic.cot | 7 | 7 | ✅ PASS |
| test_variable.cot | 30 | 30 | ✅ PASS |
| test_var_mut.cot | 15 | 15 | ✅ PASS |
| test_if.cot | 1 | 1 | ✅ PASS |
| test_while.cot | 45 | 45 | ✅ PASS |
| test_for.cot | 45 | 45 | ✅ PASS |
| test_fn.cot | 7 | 7 | ✅ PASS |
| test_recursion_simple.cot | 10 | 10 | ✅ PASS |
| test_recursion.cot | 55 | 55 | ✅ PASS |
| test_struct.cot | 7 | 7 | ✅ PASS |
| test_enum.cot | 1 | 1 | ✅ PASS |
| test_string.cot | 5 | 5 | ✅ PASS |

**12/12 tests pass.** All tests passing after Bug #1 fix.

### Bug #1: Dual Recursive Call Result Corruption - FIXED
- **Test:** test_recursion.cot (fibonacci)
- **Symptom:** `fib(10)` returns 5 instead of 55
- **Root Cause:** Call results in r15 were only tracked in `last_result`. When a subsequent instruction (like `sub`) set its result as `last_result`, the previous call result was lost. Later, `getValueInReg` couldn't find the first call's result.
- **Fix Location:** `cot/src/ir/emit_instruction.zig:emitUserCall()` - Now stores call results to a slot immediately after the call, so they can be recovered via `value_slots` even after `last_result` is overwritten.
- **Impact:** Any expression with multiple function calls in the same statement now works correctly.
- **Verified:** `fib(10)` now returns 55 ✅

## Files Created

```
tests/bootstrap/
  test_return.cot      # Just return 42 ✅
  test_arithmetic.cot  # Basic math ✅
  test_variable.cot    # Variable declaration ✅
  test_var_mut.cot     # Mutable variable ✅
  test_if.cot          # If/else ✅
  test_while.cot       # While loop ✅
  test_for.cot         # For loop ✅
  test_fn.cot          # Function call ✅
  test_recursion.cot   # Fibonacci (dual recursion) ✅
  test_recursion_simple.cot # Simple recursion ✅
  test_struct.cot      # Struct init and access ✅
  test_enum.cot        # Enum and switch ✅
  test_string.cot      # String length ✅

bootstrap/
  main.cot             # Bootstrap compiler driver (TODO)
```

---

## What We DON'T Need for Bootstrap

These features can be deferred:
- ISAM I/O operations (DBL-specific)
- Decimal types with precision/scale
- Weak references, ARC
- Trait objects/vtables
- Full closure capture (can use simpler patterns)
- Comptime evaluation (can evaluate manually)
