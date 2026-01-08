# Parser AST Population Fix

**Created:** 2026-01-07
**Status:** COMPLETED (2026-01-08)
**Priority:** CRITICAL - Blocks all downstream phases

## Completion Summary

All parser AST population issues have been resolved:
- ✅ Allocation infrastructure added to `ast.cot` (allocExpr, allocStmt, allocTypeRef)
- ✅ All 16 expression makers properly store child nodes
- ✅ All 7 type parsing functions properly store inner types
- ✅ All 18 statement makers properly store child nodes
- ✅ No remaining TODOs in parser.cot
- ✅ Integration test passes: binary expressions, method calls, struct init, switch, loops, defer

## Original Problem Statement

The parser successfully validates Cot syntax but **did not populate AST child nodes**. All `make*Expr` and `make*Stmt` helper functions created nodes with correct structure but left child references as `null` with TODO comments.

Example of original broken code:
```cot
fn makeBinaryExpr(op: TokenType, left: Expr, right: Expr, loc: SourceLoc) Expr {
    var e = makeDefaultExpr(ExprKind.BinaryExpr, loc)
    e.op = op
    // TODO: Need to store left and right somehow  <-- NOT STORED!
    return e
}
```

**Impact:** Without proper AST construction:
- Type checker cannot traverse expressions
- IR lowering cannot generate code
- Bytecode emission is impossible
- Bootstrap is blocked

## Root Cause

The AST structs in `ast.cot` use pointer types (`?*Expr`, `?*Stmt`, `[]*Expr`) for child nodes. To populate these, we need to:
1. Allocate child nodes on the heap (or use arena/pool)
2. Assign pointers to the allocated children

Cot now supports `List<T>` which can hold structs, so we can use lists to manage collections of child nodes.

## Fix Strategy

For single child references (`?*Expr`):
```cot
fn makeBinaryExpr(op: TokenType, left: Expr, right: Expr, loc: SourceLoc) Expr {
    var e = makeDefaultExpr(ExprKind.BinaryExpr, loc)
    e.op = op
    e.left = allocExpr(left)   // Allocate and return pointer
    e.right = allocExpr(right)
    return e
}
```

For collections (`[]*Expr`, `[]Param`, etc.):
```cot
fn makeCallExpr(callee: Expr, args: List<Expr>, loc: SourceLoc) Expr {
    var e = makeDefaultExpr(ExprKind.CallExpr, loc)
    e.callee = allocExpr(callee)
    e.args = listToSlice(args)  // Convert List to slice
    return e
}
```

## Allocation Approach

Add to `ast.cot` or `parser.cot`:
```cot
// Global arena for AST nodes (or use module-level list)
var expr_arena: List<Expr> = List.new()
var stmt_arena: List<Stmt> = List.new()
var type_arena: List<TypeRef> = List.new()

fn allocExpr(e: Expr) *Expr {
    expr_arena.push(e)
    return &expr_arena.get(expr_arena.len() - 1)
}

fn allocStmt(s: Stmt) *Stmt {
    stmt_arena.push(s)
    return &stmt_arena.get(stmt_arena.len() - 1)
}

fn allocTypeRef(t: TypeRef) *TypeRef {
    type_arena.push(t)
    return &type_arena.get(type_arena.len() - 1)
}
```

---

## Detailed TODO List

### Category 1: Expression Makers (16 TODOs)

| Line | Function | Missing Storage | Fix |
|------|----------|-----------------|-----|
| 824 | `makeUnaryExpr` | operand | `e.operand = allocExpr(operand)` |
| 831 | `makeBinaryExpr` | left, right | `e.left = allocExpr(left); e.right = allocExpr(right)` |
| 838 | `makeCallExpr` | callee | `e.callee = allocExpr(callee)` + args slice |
| 845 | `makeFieldExpr` | object | `e.object = allocExpr(object)` |
| 851 | `makeIndexExpr` | object, index | `e.object = allocExpr(object); e.index = allocExpr(index)` |
| 858 | `makeDerefExpr` | operand | `e.operand = allocExpr(operand)` |
| 865 | `makeSliceExpr` | object, start, end | `e.object = allocExpr(object); e.slice_start = allocExpr(start); e.slice_end = allocExpr(end)` |
| 873 | `makeOptionalFieldExpr` | object | `e.object = allocExpr(object)` |
| 880 | `makeOptionalIndexExpr` | object, index | `e.object = allocExpr(object); e.index = allocExpr(index)` |
| 887 | `makeRangeExpr` | start, end | `e.range_start = allocExpr(start); e.range_end = allocExpr(end)` |
| 893 | `makeCastExpr` | expr, target_type | `e.operand = allocExpr(expr); e.cast_type = allocTypeRef(target_type)` |
| 901 | `makeIsExpr` | expr, check_type | `e.operand = allocExpr(expr)` + type check storage |
| 909 | `makeStructInitExpr` | field initializers | Convert `List<FieldInit>` to slice |
| 916 | `makeArrayInitExpr` | elements | Convert `List<Expr>` to `[]*Expr` slice |
| 923 | `makeLambdaExpr` | params, body | Store params slice and body expr |
| 930 | `makeInterpStringExpr` | parts | Store alternating string/expr parts |

### Category 2: Type Parsing (7 TODOs)

| Line | Context | Missing Storage | Fix |
|------|---------|-----------------|-----|
| 1747 | Pointer type `*T` | inner type | `type_ref.inner = allocTypeRef(inner)` |
| 1762 | Optional type `?T` | inner type | `type_ref.inner = allocTypeRef(inner)` |
| 1777 | Array type `[N]T` | element type | `type_ref.inner = allocTypeRef(elem)` |
| 1792 | Slice type `[]T` | element type | `type_ref.inner = allocTypeRef(elem)` |
| 1811 | Generic type `T[U]` | type arguments | Convert args list to slice |
| 1824 | Function type `fn(A) B` | param types | Store param types slice |
| 1825 | Function type `fn(A) B` | return type | `type_ref.return_type = allocTypeRef(ret)` |

### Category 3: Statement Makers (18 TODOs)

| Line | Function/Context | Missing Storage | Fix |
|------|------------------|-----------------|-----|
| 2048 | Expression statement | expr | `stmt.expr = allocExpr(e)` |
| 2064 | Return statement | return value | `stmt.return_value = allocExpr(val)` |
| 2069 | If statement | condition, branches | All three fields |
| 2074 | While statement | condition, body | Both fields |
| 2081 | For statement | iterator, body | Both fields |
| 2086 | Block statement | statements | Convert to slice |
| 2091 | Switch statement | expression, arms | Both fields |
| 2104 | Loop statement | body | `stmt.loop_body = allocStmt(body)` |
| 2109 | Defer statement | deferred expr | `stmt.defer_expr = allocExpr(e)` |
| 2116 | Try statement | try body, catch body | Both fields |
| 2121 | Throw statement | thrown expr | `stmt.throw_expr = allocExpr(e)` |
| 2128 | Test declaration | body | `stmt.test_body = allocStmt(body)` |
| 2135 | Union declaration | fields | Convert to slice |
| 2142 | Type alias | aliased type | `stmt.alias_type = allocTypeRef(t)` |
| 2215 | Function decl | params, body | Params slice + body stmt |
| 2222 | Struct decl | fields | Convert to slice |
| 2229 | Enum decl | variants | Convert to slice |
| 2236 | Impl decl | type, methods | Type ref + methods slice |

---

## Execution Plan

### Step 1: Add Allocation Infrastructure (30 min)

Add to `ast.cot`:
```cot
// AST node arenas
var g_expr_arena: List<Expr> = List.new()
var g_stmt_arena: List<Stmt> = List.new()
var g_type_arena: List<TypeRef> = List.new()
var g_param_arena: List<Param> = List.new()
var g_field_arena: List<Field> = List.new()
var g_field_init_arena: List<FieldInit> = List.new()
var g_variant_arena: List<EnumVariant> = List.new()
var g_arm_arena: List<SwitchArm> = List.new()

fn allocExpr(e: Expr) *Expr {
    g_expr_arena.push(e)
    return &g_expr_arena.get(g_expr_arena.len() - 1)
}

fn allocStmt(s: Stmt) *Stmt {
    g_stmt_arena.push(s)
    return &g_stmt_arena.get(g_stmt_arena.len() - 1)
}

fn allocTypeRef(t: TypeRef) *TypeRef {
    g_type_arena.push(t)
    return &g_type_arena.get(g_type_arena.len() - 1)
}

// Clear arenas between parses
fn clearASTArenas() {
    g_expr_arena.clear()
    g_stmt_arena.clear()
    g_type_arena.clear()
    g_param_arena.clear()
    g_field_arena.clear()
    g_field_init_arena.clear()
    g_variant_arena.clear()
    g_arm_arena.clear()
}
```

### Step 2: Fix Expression Makers (45 min)

Update each `make*Expr` function to use allocation. Example:

```cot
fn makeBinaryExpr(op: TokenType, left: Expr, right: Expr, loc: SourceLoc) Expr {
    var e = makeDefaultExpr(ExprKind.BinaryExpr, loc)
    e.op = op
    e.left = allocExpr(left)
    e.right = allocExpr(right)
    return e
}
```

**Order of fixes:**
1. `makeUnaryExpr` - simple, one operand
2. `makeBinaryExpr` - two operands
3. `makeCallExpr` - callee + args list
4. `makeFieldExpr`, `makeIndexExpr` - object + field/index
5. `makeSliceExpr` - object + start + end
6. `makeOptionalFieldExpr`, `makeOptionalIndexExpr`
7. `makeRangeExpr`, `makeCastExpr`
8. `makeStructInitExpr`, `makeArrayInitExpr` - list to slice
9. `makeLambdaExpr`, `makeInterpStringExpr` - complex

### Step 3: Fix Type Parsing (30 min)

Update `parseType` and helper functions:
- Pointer: store inner type
- Optional: store inner type
- Array/Slice: store element type
- Function: store param types + return type
- Generic: store type arguments

### Step 4: Fix Statement Makers (45 min)

Update each statement maker:
1. Simple ones: `makeExprStmt`, `makeReturnStmt`, `makeThrowStmt`, `makeDeferStmt`
2. Control flow: `makeIfStmt`, `makeWhileStmt`, `makeForStmt`, `makeLoopStmt`
3. Block: `makeBlockStmt` - convert List<Stmt> to []*Stmt
4. Switch: `makeSwitchStmt` - expr + arms slice
5. Try/catch: `makeTryStmt`
6. Declarations: fn, struct, enum, impl, union, type alias, test

### Step 5: Clean Up (15 min)

1. Remove all debug `println` statements (lines 59-63, 114-122)
2. Remove all `// TODO:` comments for completed items
3. Verify no remaining TODOs

### Step 6: Integration Test (30 min)

Create test that:
1. Parses a file with all expression/statement types
2. Walks the AST to verify all children are populated
3. Runs through type checker to verify traversal works

---

## Estimated Time

| Task | Time |
|------|------|
| Step 1: Allocation infrastructure | 30 min |
| Step 2: Expression makers | 45 min |
| Step 3: Type parsing | 30 min |
| Step 4: Statement makers | 45 min |
| Step 5: Clean up | 15 min |
| Step 6: Integration test | 30 min |
| **Total** | **~3 hours** |

---

## Verification Checklist

- [x] All 41 TODOs in parser.cot are resolved
- [x] No debug println statements remain (only legitimate error reporting)
- [x] AST traversal test passes
- [x] Type checker can process parsed AST
- [ ] driver.cot can integrate parser with type checker (future work)

## Dependencies

- `List<T>` struct storage (VERIFIED WORKING)
- Pointer semantics for struct fields (VERIFIED WORKING)
- Arena allocation pattern with List (VERIFIED WORKING)
- `new T{...}` heap allocation syntax (VERIFIED WORKING)
- `List.to_slice()` conversion (VERIFIED WORKING)

## Implementation Notes

The final implementation uses `new T{...}` syntax in `makeDefaultExpr` and `makeDefaultStmt` to heap-allocate AST nodes directly, avoiding the need for separate arena allocation functions for the constructors. The arena functions in `ast.cot` remain available for future use if needed.
