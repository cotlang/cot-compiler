# Bootstrap Plan - Updated 2026-01-07

## Current State

| File | Lines | Status |
|------|-------|--------|
| token.cot | 471 | Complete |
| lexer.cot | 471 | Complete |
| ast.cot | 200 | Complete |
| parser.cot | 1,469 | Complete |
| types.cot | 880 | Complete |
| type_checker.cot | 1,565 | Complete |
| ir.cot | 585 | Complete |
| lower.cot | 777 | **Partial** |
| emit.cot | 0 | **Not Started** |
| **Total** | ~6,418 | ~75% |

## Critical Path to Bootstrap

### Phase 4A: Complete Lowering (lower.cot)

Missing expression lowering:
- [ ] StructInitExpr - struct initialization `Foo{ .x = 1 }`
- [ ] ArrayInitExpr - array initialization `[1, 2, 3]`
- [ ] AssignExpr - assignment `x = y`
- [ ] CastExpr - type casts `x as i32`
- [ ] SliceExpr - slicing `arr[1..3]`
- [ ] MethodCallExpr - method calls `obj.method()`

Missing statement lowering:
- [ ] ForStmt - for loops
- [ ] SwitchStmt - switch statements
- [ ] StructDecl - struct definitions (emit type info)
- [ ] EnumDecl - enum definitions
- [ ] ImplDecl - impl blocks

### Phase 5: Bytecode Emission (emit.cot)

- [ ] Create opcodes.cot - opcode definitions matching Zig VM
- [ ] Create emit.cot - IR to bytecode translation
- [ ] Constant pool emission
- [ ] Function table emission
- [ ] Module header/footer

### Phase 6: Bootstrap Test

- [ ] Compile token.cot with self-hosted compiler
- [ ] Compare output with Zig-compiled version
- [ ] Progressively compile more modules

## Focused Next Steps

1. **Add StructInitExpr lowering** - needed for parser.cot
2. **Add ArrayInitExpr lowering** - needed for many files
3. **Add AssignExpr lowering** - needed everywhere
4. **Add ForStmt lowering** - used throughout
5. **Add SwitchStmt lowering** - used throughout
6. **Start emit.cot** - critical path

## What We DON'T Need for Bootstrap

- ISAM I/O operations (DBL-specific)
- Decimal types with precision/scale
- Weak references, ARC
- Trait objects/vtables
- Closures (can use regular functions)
