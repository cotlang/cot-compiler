# Naming Convention Alignment Plan

**Created:** 2026-01-08
**Purpose:** Establish canonical naming conventions for the Cot language and align both compilers.

## Executive Summary

The self-hosted Cot compiler will be the source of truth. After self-hosting is complete, the Zig compiler will be deprecated. This plan establishes naming conventions and identifies refactoring needed in both codebases.

---

## Canonical Cot Naming Conventions

### 1. Functions: `camelCase`

```cot
fn lowerExpr(l: Lowerer, expr: Expr) i64
fn parseStatement(self: *Parser) *Stmt
fn emitInstruction(e: Emitter, op: IROp)
```

**Constructors:** Use `new` prefix consistently:
```cot
fn newLowerer() Lowerer
fn newIRModule(name: string) IRModule
fn newParser(source: string) Parser
```

**NOT:** `create`, `make`, `init` (pick one and stick with it)

### 2. Types/Structs: `PascalCase`

```cot
struct Parser { }
struct Lowerer { }
struct TypeChecker { }
```

**IR-specific types:** Use `IR` prefix for clarity:
```cot
struct IRModule { }
struct IRFunction { }
struct IRBlock { }
struct IRInst { }
struct IRType { }
struct IRValue { }
```

### 3. Enums: `PascalCase`

```cot
enum TokenType { Plus, Minus, ... }
enum StmtKind { IfStmt, WhileStmt, ... }
enum ExprKind { BinaryExpr, UnaryExpr, ... }
```

**IR-specific enums:** Use `IR` prefix:
```cot
enum IROp { IAdd, ISub, Load, Store, ... }
enum IRTypeTag { Void, Bool, I64, ... }
```

### 4. Enum Variants: `PascalCase`

```cot
enum TokenType {
    Plus,
    Minus,
    LeftParen,
    RightParen,
    KwFn,        // Keywords prefixed with Kw
    KwStruct,
    KwIf,
}
```

### 5. Variables and Fields: `snake_case`

```cot
var current_token: Token
var had_error: bool
const module_name: string
```

**Index values:** Use `_idx` or `_id` suffix:
```cot
var current_func_idx: i64
var type_id: i64
var block_id: i64
```

### 6. Constants: `SCREAMING_SNAKE_CASE`

```cot
const MAX_ERRORS: i64 = 100
const MAGIC_HEADER: string = "CBO1"
const VERSION_MAJOR: i64 = 1
```

### 7. File Names: `snake_case.cot`

```
src/
├── token.cot
├── lexer.cot
├── parser.cot
├── ast.cot
├── types.cot
├── type_checker.cot
├── ir.cot
├── lower.cot
├── emit.cot
└── driver.cot
```

### 8. Method Organization: `impl` blocks

```cot
impl Parser {
    fn advance(self: *Parser) { ... }
    fn check(self: *Parser, t: TokenType) bool { ... }
    fn consume(self: *Parser, t: TokenType, msg: string) { ... }
}
```

**Free functions** for utility/helper functions that don't belong to a type:
```cot
fn isDigit(c: char) bool { ... }
fn isAlpha(c: char) bool { ... }
```

### 9. Boolean Naming Patterns

Use descriptive prefixes:
```cot
var had_error: bool      // Past tense for state
var is_mutable: bool     // "is" for properties
var in_loop: bool        // "in" for context
var can_assign: bool     // "can" for capabilities
var has_payload: bool    // "has" for presence
```

---

## Inconsistencies to Fix

### In Self-Hosted Cot Compiler (`cot-compiler/src/`)

| File | Current | Should Be | Notes |
|------|---------|-----------|-------|
| `lower.cot` | `lowerGetCurrentFunc` | `getCurrentFunc` or keep in `impl Lowerer` | Redundant `lower` prefix |
| `lower.cot` | `lowerNewValue` | `newValue` or `allocValue` | Redundant prefix |
| `lower.cot` | `lowerCreateBlock` | `createBlock` | Redundant prefix |
| `lower.cot` | `lowerDefineVar` | `defineVar` | Redundant prefix |
| `lower.cot` | `lowerEmit` | `emit` | Redundant prefix |
| `lower.cot` | `lowerEnterScope` | `enterScope` | Redundant prefix |
| `lower.cot` | `lowerExitScope` | `exitScope` | Redundant prefix |
| `lower.cot` | `lowerSwitchBlock` | `switchToBlock` | Redundant prefix |
| `types.cot` | `regGetType` | `getType` or in `impl TypeRegistry` | Redundant prefix |
| `types.cot` | `regAddType` | `addType` or in `impl TypeRegistry` | Redundant prefix |
| `types.cot` | `regAddPointerType` | `addPointerType` | Redundant prefix |
| `ir.cot` | `fnNewValue` | `newValue` or in `impl IRFunction` | Redundant prefix |
| `ir.cot` | `fnCreateBlock` | `createBlock` or in `impl IRFunction` | Redundant prefix |
| `ir.cot` | `fnGetBlock` | `getBlock` or in `impl IRFunction` | Redundant prefix |
| `ir.cot` | `blockAppend` | `append` or in `impl IRBlock` | Redundant prefix |
| `ir.cot` | `blockIsTerminated` | `isTerminated` or in `impl IRBlock` | Redundant prefix |
| `ir.cot` | `modAddFunction` | `addFunction` or in `impl IRModule` | Redundant prefix |
| `ir.cot` | `modAddGlobal` | `addGlobal` or in `impl IRModule` | Redundant prefix |
| `ir.cot` | `modAddString` | `addString` or in `impl IRModule` | Redundant prefix |
| `ir.cot` | `irRegAddType` | `addType` or in `impl IRTypeRegistry` | Redundant prefix |
| `ir.cot` | `irRegGetType` | `getType` or in `impl IRTypeRegistry` | Redundant prefix |
| `ir.cot` | `irTypeIsInteger` | `isInteger` or in `impl IRType` | Redundant prefix |
| `ir.cot` | `irTypeIsFloat` | `isFloat` or in `impl IRType` | Redundant prefix |
| `type_checker.cot` | `isErrorTypeId` | `isErrorType` or in `impl TypeRegistry` | Cleaner |

### In Zig Compiler (`cot/src/`) - Align to Match Cot

| File | Current | Should Match Cot | Notes |
|------|---------|------------------|-------|
| `parser/parser.zig` | `parseFnDef` | `parseFunctionDecl` | Match Cot naming |
| `parser/parser.zig` | `parseStructDef` | `parseStructDecl` | Match Cot naming |
| `parser/parser.zig` | `parseEnumDef` | `parseEnumDecl` | Match Cot naming |
| `ir/lower.zig` | `lower` | `lowerModule` | More explicit |
| Various | `create*` functions | `new*` | Standardize on `new` |

---

## Refactoring Plan

### Phase 1: Move to `impl` Blocks (High Impact)

Convert free functions with type prefixes to impl blocks.

**ir.cot changes:**
```cot
// Before:
fn fnNewValue(func: IRFunction) i64 { ... }
fn fnCreateBlock(func: IRFunction, label: string) i64 { ... }
fn fnGetBlock(func: IRFunction, id: i64) IRBlock { ... }

// After:
impl IRFunction {
    fn newValue(self: *IRFunction) i64 { ... }
    fn createBlock(self: *IRFunction, label: string) i64 { ... }
    fn getBlock(self: *IRFunction, id: i64) IRBlock { ... }
}
```

**Files to update:**
- [x] `ir.cot` - IRFunction, IRBlock, IRModule, IRTypeRegistry methods ✅ (2026-01-08)
- [x] `types.cot` - TypeRegistry methods ✅ (2026-01-08)
- [x] `lower.cot` - Lowerer helper methods moved to impl block ✅ (2026-01-08)

### Phase 2: Remove Redundant Prefixes (Medium Impact)

For functions that stay as free functions, remove redundant module prefixes.

**lower.cot changes:**
```cot
// Before:
fn lowerNewValue(l: Lowerer) i64
fn lowerCreateBlock(l: Lowerer, label: string) i64
fn lowerEmit(l: Lowerer, inst: IRInst)

// After (if keeping as free functions):
fn allocValue(l: Lowerer) i64
fn createBlock(l: Lowerer, label: string) i64
fn emit(l: Lowerer, inst: IRInst)
```

### Phase 3: Align Zig Compiler (Low Priority)

Update Zig compiler to match Cot conventions where divergent. Lower priority since Zig compiler will be deprecated.

---

## Implementation Order

1. **Phase 1a:** `ir.cot` - Add impl blocks for IRFunction, IRBlock, IRModule ✅ COMPLETE
2. **Phase 1b:** `ir.cot` - Add impl block for IRTypeRegistry ✅ COMPLETE
3. **Phase 1c:** `types.cot` - Add impl block for TypeRegistry ✅ COMPLETE
4. **Phase 2a:** `lower.cot` - Add impl block for Lowerer with helper methods ✅ COMPLETE
5. **Phase 2b:** `type_checker.cot` - Update function names (deferred - already idiomatic)
6. **Phase 3:** Zig compiler alignment (optional, lower priority - will be deprecated)

### Estimated Changes Per File

| File | Functions to Move/Rename | Approx Call Sites |
|------|-------------------------|-------------------|
| `ir.cot` | ~15 functions | ~50 call sites |
| `types.cot` | ~10 functions | ~30 call sites |
| `lower.cot` | ~20 functions | ~100 call sites |
| `type_checker.cot` | ~5 functions | ~20 call sites |

---

## Verification

After each phase:
```bash
cd ~/cotlang/cot-compiler
cot compile src/parser.cot -o /tmp/parser.cbo
cot compile src/lower.cot -o /tmp/lower.cbo
cot compile src/type_checker.cot -o /tmp/type_checker.cbo
cot compile src/emit.cot -o /tmp/emit.cbo
```

---

## Decision: Free Functions vs Impl Blocks

**Use `impl` blocks when:**
- The function primarily operates on one type
- It's a method that "belongs" to the type conceptually
- Example: `IRFunction.createBlock()`, `Parser.advance()`

**Use free functions when:**
- The function is a pure utility (no primary type)
- The function coordinates between multiple types equally
- Example: `isDigit(c)`, `lowerExpr(l, expr)` (operates on both Lowerer and Expr)

For `lower.cot`, most `lowerXxx` functions should remain free functions since they operate on both the Lowerer and AST nodes. But helper functions like `lowerNewValue`, `lowerCreateBlock` should move to impl blocks.

---

## Appendix: Quick Reference

```
Functions:      camelCase           lowerExpr, parseStatement
Constructors:   newTypeName         newParser, newLowerer
Types:          PascalCase          Parser, Lowerer, IRModule
Enums:          PascalCase          TokenType, IROp, StmtKind
Variants:       PascalCase          Plus, Minus, KwFn
Variables:      snake_case          current_token, had_error
Index vars:     snake_case_idx      func_idx, block_id
Constants:      SCREAMING_SNAKE     MAX_ERRORS, MAGIC_HEADER
Files:          snake_case.cot      type_checker.cot, lower.cot
```
