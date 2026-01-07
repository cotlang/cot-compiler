# Detailed Requirements Analysis

**Date:** 2025-01-07
**Purpose:** Comprehensive breakdown of what the Cot self-hosted compiler needs to replicate from the Zig implementation.

## Executive Summary

The current Zig implementation is **~107,000 lines**. The Cot compiler currently has **~4,500 lines** (~4%).

| Component | Zig Lines | Cot Lines | Status |
|-----------|-----------|-----------|--------|
| Lexer | ~1,000 | 471 | ✅ Complete |
| Parser | ~3,131 | 1,469 | ✅ Complete |
| AST | ~5,130 | 309 | ⚠️ Minimal |
| Type Checker | ~2,211 | 1,935 | 🔄 In Progress |
| IR Module | ~16,879 | 0 | ❌ Not Started |
| Bytecode Emission | ~3,500 | 0 | ❌ Not Started |
| **Subtotal (Compiler)** | **~31,851** | **~4,184** | **13%** |

**Note:** The VM/Runtime (~15,748 lines) stays in Zig for bootstrap.

---

## Phase 3: Type System (REVISED)

### 3.1 Type Registry (`types.cot`) - PARTIAL
Current: 662 lines

**Implemented:**
- [x] Basic type definitions (TypeKind enum)
- [x] TypeRegistry struct
- [x] Primitive type registration (i8-i64, u8-u64, f32, f64, bool, string, void)
- [x] Type lookup by ID

**Missing:**
- [ ] Pointer type construction (`*T`, `*const T`)
- [ ] Optional type construction (`?T`)
- [ ] Array type construction (`[N]T`)
- [ ] Slice type construction (`[]T`)
- [ ] Function type construction (`fn(A, B) -> R`)
- [ ] Struct type registration with fields
- [ ] Enum type registration with variants
- [ ] Generic type instantiation
- [ ] Type compatibility checking
- [ ] Type coercion rules

### 3.2 Type Checker (`type_checker.cot`) - PARTIAL
Current: 1,273 lines

**Implemented:**
- [x] Basic expression type inference
- [x] Binary operation type checking
- [x] Function call type checking
- [x] Struct field access
- [x] Variable declaration checking

**Missing:**
- [ ] Method resolution (impl blocks)
- [ ] Generic type inference
- [ ] Trait bounds checking
- [ ] Lifetime/ownership analysis (if applicable)
- [ ] Exhaustive switch checking
- [ ] Unreachable code detection
- [ ] Return type verification for all paths

### 3.3 Diagnostics
**Missing entirely:**
- [ ] Error message formatting with source context
- [ ] Warning levels
- [ ] Error recovery and multiple error reporting
- [ ] Diagnostic codes (E001, W001, etc.)

---

## Phase 4: IR Module (NEW - CRITICAL)

This is the largest missing piece. The Zig IR module is **~16,879 lines**.

### 4.1 IR Representation (`ir.cot`)
Reference: `src/ir/ir.zig` (1,541 lines)

**Required structures:**
- [ ] `IR.Type` - IR type representation
- [ ] `IR.Value` - IR value with type and ID
- [ ] `IR.Instruction` - All IR operations
- [ ] `IR.BasicBlock` - Control flow blocks
- [ ] `IR.Function` - Function with blocks, params, locals
- [ ] `IR.Module` - Top-level container

**IR Instructions needed (from ir.zig):**
```
// Constants
iconst, fconst, sconst, bconst, null_const

// Arithmetic
iadd, isub, imul, idiv, imod, ineg
fadd, fsub, fmul, fdiv, fneg

// Comparison
icmp_eq, icmp_ne, icmp_lt, icmp_le, icmp_gt, icmp_ge
fcmp_eq, fcmp_ne, fcmp_lt, fcmp_le, fcmp_gt, fcmp_ge

// Logical/Bitwise
log_and, log_or, log_not
band, bor, bxor, bnot, shl, shr

// Memory
alloca, load, store, field_ptr, index_ptr

// Control flow
br, br_cond, ret, ret_void, call, call_native

// Type operations
cast, is_null, unwrap_optional

// Struct/Array
struct_init, array_init, slice_init

// String operations
str_concat, str_len, str_index, str_slice
```

### 4.2 AST to IR Lowering (`lower.cot`)
Reference: `src/ir/lower.zig` + `lower_expr.zig` + `lower_stmt.zig` (~6,789 lines)

**Core lowering functions:**
- [ ] `lowerModule(ast) -> IR.Module`
- [ ] `lowerFunction(fn_decl) -> IR.Function`
- [ ] `lowerStatement(stmt) -> void` (emits instructions)
- [ ] `lowerExpression(expr) -> IR.Value`

**Statement lowering:**
- [ ] Variable declarations (var, const)
- [ ] Assignments (simple, compound, destructuring)
- [ ] If/else statements
- [ ] While loops
- [ ] For-in loops (range, array, slice)
- [ ] Switch statements
- [ ] Return statements
- [ ] Block statements
- [ ] Expression statements

**Expression lowering:**
- [ ] Literals (int, float, string, bool, null)
- [ ] Identifiers (local, global, function)
- [ ] Binary operations (20+ operators)
- [ ] Unary operations (-, !, ~, &, .*)
- [ ] Function calls
- [ ] Method calls
- [ ] Field access
- [ ] Index access
- [ ] Struct initialization
- [ ] Array initialization
- [ ] Lambda expressions
- [ ] Range expressions

### 4.3 Scope Management (`scope.cot`)
Reference: `src/ir/scope_stack.zig` (264 lines)

- [ ] Scope stack for nested blocks
- [ ] Variable lookup (local → enclosing → global)
- [ ] Shadowing support
- [ ] Scope entry/exit

### 4.4 Closure Handling (`closure.cot`)
Reference: `src/ir/closure.zig` (359 lines)

- [ ] Free variable detection
- [ ] Environment capture
- [ ] Closure creation

### 4.5 IR Optimization (`optimize.cot`) - OPTIONAL FOR BOOTSTRAP
Reference: `src/ir/optimize.zig` (1,722 lines)

- [ ] Constant folding
- [ ] Dead code elimination
- [ ] Copy propagation
- [ ] Common subexpression elimination

---

## Phase 5: Bytecode Emission (NEW - CRITICAL)

### 5.1 Bytecode Format (`bytecode.cot`)
Reference: `src/runtime/bytecode/module.zig` + `opcodes.zig` (~1,636 lines)

**Module format:**
- [ ] Magic number and version
- [ ] Constant pool (strings, numbers)
- [ ] Function table
- [ ] Code section
- [ ] Debug info (line numbers, source maps)

**Opcode definitions:**
- [ ] All ~150 opcodes from opcodes.zig
- [ ] Operand encoding (register, immediate, offset)

### 5.2 Code Emission (`emit.cot`)
Reference: `src/ir/emit_bytecode.zig` + `emit_instruction.zig` (~3,506 lines)

- [ ] IR to bytecode translation
- [ ] Register allocation (simple linear scan)
- [ ] Label resolution (jumps, branches)
- [ ] Constant pool building
- [ ] Function prologue/epilogue
- [ ] Stack frame management

### 5.3 Binary Writer
- [ ] Write bytecode module to .cbo file
- [ ] Proper byte ordering (little-endian)
- [ ] Alignment and padding

---

## Phase 6: Bootstrap (REVISED)

### 6.1 Self-Compilation Test
- [ ] Compile token.cot with Cot compiler
- [ ] Compile lexer.cot with Cot compiler
- [ ] Compile ast.cot with Cot compiler
- [ ] Compile parser.cot with Cot compiler
- [ ] Compile types.cot with Cot compiler
- [ ] Compile type_checker.cot with Cot compiler
- [ ] Compile ir.cot with Cot compiler
- [ ] Compile emit.cot with Cot compiler
- [ ] Full self-compilation

### 6.2 Verification
- [ ] Compare output of Zig-compiled vs Cot-compiled compiler
- [ ] Run test suite with self-compiled compiler

---

## Estimated Effort

| Phase | Estimated Cot Lines | Zig Reference Lines | Complexity |
|-------|--------------------|--------------------|------------|
| 3. Type System (complete) | ~2,500 | ~2,200 | Medium |
| 4. IR Module | ~8,000-10,000 | ~16,879 | High |
| 5. Bytecode Emission | ~3,000-4,000 | ~3,500 | High |
| 6. Bootstrap | ~500 | N/A | Medium |
| **Total New Code** | **~14,000-17,000** | - | - |

**Current progress: ~4,500 lines (~25-30% of target)**

---

## Recommended Order

1. **Complete Type System** (Phase 3)
   - Finish type_checker.cot
   - Add comprehensive type rules

2. **IR Representation** (Phase 4.1)
   - Define IR data structures
   - This is the foundation for everything else

3. **Expression Lowering** (Phase 4.2 partial)
   - Start with simple expressions
   - Build up incrementally

4. **Statement Lowering** (Phase 4.2 partial)
   - var/const declarations
   - Control flow (if, while, for)

5. **Bytecode Format** (Phase 5.1)
   - Define module structure
   - Opcode encoding

6. **Code Emission** (Phase 5.2)
   - Translate IR to bytecode

7. **Bootstrap** (Phase 6)
   - Self-compile and verify

---

## Key Dependencies

```
Parser (done)
    ↓
Type Checker (in progress)
    ↓
IR Lowering ← IR Representation
    ↓
Bytecode Emission ← Bytecode Format
    ↓
Bootstrap
```

The critical path is: **Type Checker → IR → Bytecode**
