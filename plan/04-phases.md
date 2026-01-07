# Implementation Phases

## Phase 0: Prerequisites (3-5 days)

**Goal:** Verify Cot has all features needed for compiler development.

### Tasks

#### 0.1 Create Test Suite
- [ ] Create `~/cotlang/cot-compiler/tests/prerequisites.cot`
- [ ] Test character access: `char_at(str, i)`
- [ ] Test dynamic arrays: `[]T` with push/append
- [ ] Test Map methods: `.get()`, `.put()`, `.has()`
- [ ] Test enum match syntax
- [ ] Test struct methods with mutable self
- [ ] Test self-referential structs
- [ ] Test optional unwrapping

#### 0.2 Implement Missing Features
- [ ] `char_at(str, i)` native if missing
- [ ] `array_push(arr, item)` native if missing
- [ ] Fix any issues found in testing

#### 0.3 Documentation
- [ ] Document working syntax for each feature
- [ ] Create "Cot for compiler writers" cheat sheet

### Exit Criteria
- All prerequisite tests pass
- Can write: struct with methods, map usage, enum matching, array building

---

## Phase 1: Lexer (2-3 days)

**Goal:** Tokenize Cot source code.

### Tasks

#### 1.1 Token Types (~100 lines)
- [ ] Create `src/token.cot`
- [ ] Define `TokenType` enum (50+ variants)
- [ ] Define `Token` struct
- [ ] Define `SourceLoc` struct

#### 1.2 Lexer Core (~300 lines)
- [ ] Create `src/lexer.cot`
- [ ] Implement `Lexer` struct with source, position, line, column
- [ ] Implement `new(source)` constructor
- [ ] Implement `tokenize()` → `[]Token`
- [ ] Implement `advance()`, `peek()`, `peekNext()`
- [ ] Implement `isAtEnd()`

#### 1.3 Token Scanning (~200 lines)
- [ ] Implement `scanToken()` main dispatch
- [ ] Implement `skipWhitespace()` including comments
- [ ] Implement `scanString()` with escape sequences
- [ ] Implement `scanNumber()` (int and float)
- [ ] Implement `scanIdentifier()` with keyword detection
- [ ] Implement single/double character operators

#### 1.4 Keyword Table
- [ ] Create keyword lookup (map or if-chain)
- [ ] All Cot keywords: fn, let, const, if, else, while, for, return, struct, enum, impl, trait, match, etc.

#### 1.5 Testing
- [ ] Create `tests/lexer_test.cot`
- [ ] Test basic tokens: identifiers, numbers, strings
- [ ] Test operators: +, -, *, /, ==, !=, etc.
- [ ] Test keywords
- [ ] Test edge cases: empty input, unterminated string, etc.

### Exit Criteria
- Can tokenize real Cot source files
- Produces same token sequence as Zig lexer for test files

---

## Phase 2: Parser (5-7 days)

**Goal:** Parse tokens into AST.

### Tasks

#### 2.1 AST Definitions (~400 lines)
- [ ] Create `src/ast.cot`
- [ ] Define `StmtKind` enum
- [ ] Define `ExprKind` enum
- [ ] Define `TypeKind` enum
- [ ] Define `Stmt`, `Expr`, `TypeRef` structs
- [ ] Helper constructors for each node type

#### 2.2 Parser Infrastructure (~200 lines)
- [ ] Create `src/parser.cot`
- [ ] Implement `Parser` struct
- [ ] Implement `new(tokens)` constructor
- [ ] Implement `advance()`, `peek()`, `previous()`
- [ ] Implement `check()`, `match()`, `consume()`
- [ ] Implement error recovery: `error()`, `synchronize()`

#### 2.3 Statement Parsing (~500 lines)
- [ ] Implement `parse()` → `[]Stmt`
- [ ] Implement `declaration()`
- [ ] Implement `letDeclaration()` / `constDeclaration()`
- [ ] Implement `functionDeclaration()`
- [ ] Implement `structDeclaration()`
- [ ] Implement `enumDeclaration()`
- [ ] Implement `implBlock()`
- [ ] Implement `blockStatement()`
- [ ] Implement `ifStatement()`
- [ ] Implement `whileStatement()`
- [ ] Implement `forStatement()`
- [ ] Implement `returnStatement()`
- [ ] Implement `expressionStatement()`

#### 2.4 Expression Parsing - Pratt (~600 lines)
- [ ] Implement Precedence enum
- [ ] Implement `expression()`
- [ ] Implement `parsePrecedence(prec)`
- [ ] Implement prefix parsers: literals, identifiers, unary, grouping
- [ ] Implement infix parsers: binary, call, index, field access
- [ ] Implement `literal()`: int, float, string, bool, null
- [ ] Implement `identifier()`
- [ ] Implement `unary()`
- [ ] Implement `binary(left)`
- [ ] Implement `call(callee)`
- [ ] Implement `index(obj)`
- [ ] Implement `field(obj)`
- [ ] Implement `ifExpression()`
- [ ] Implement `lambda()`
- [ ] Implement `structInit()`

#### 2.5 Type Parsing (~100 lines)
- [ ] Implement `parseType()`
- [ ] Named types: `i32`, `string`, `MyStruct`
- [ ] Pointer types: `*T`
- [ ] Optional types: `?T`
- [ ] Array types: `[N]T`
- [ ] Slice types: `[]T`
- [ ] Function types: `fn(A, B) C`
- [ ] Generic types: `Map<K, V>`

#### 2.6 Testing
- [ ] Create `tests/parser_test.cot`
- [ ] Test variable declarations
- [ ] Test function declarations
- [ ] Test struct declarations
- [ ] Test expressions with precedence
- [ ] Test control flow statements
- [ ] Test error recovery
- [ ] Compare AST output with Zig parser for same input

### Exit Criteria
- Can parse real Cot source files
- Produces structurally equivalent AST to Zig parser

---

## Phase 3: Type Checker (4-5 days)

**Goal:** Validate types and build symbol tables.

### Tasks

#### 3.1 Type Definitions (~300 lines)
- [ ] Create `src/types.cot`
- [ ] Define `TypeTag` enum
- [ ] Define `Type` struct
- [ ] Define `Field`, `Variant` structs
- [ ] Implement type equality
- [ ] Implement type stringification

#### 3.2 Scope Management (~200 lines)
- [ ] Define `Scope` struct with variables map
- [ ] Implement scope stack (enter/exit)
- [ ] Implement variable definition
- [ ] Implement variable lookup (walk scope chain)

#### 3.3 Type Checker Core (~600 lines)
- [ ] Create `src/type_checker.cot`
- [ ] Implement `TypeChecker` struct
- [ ] Implement `check(stmts)` → errors
- [ ] Implement `checkStmt(stmt)`
- [ ] Implement `checkExpr(expr)` → Type
- [ ] Implement `checkType(type_ref)` → Type

#### 3.4 Statement Checking
- [ ] Check let/const: type annotation vs initializer
- [ ] Check function: param types, return type, body
- [ ] Check struct: field types, no duplicates
- [ ] Check enum: variant values
- [ ] Check impl: methods match trait if any
- [ ] Check if/while/for: condition is bool
- [ ] Check return: matches function return type

#### 3.5 Expression Checking
- [ ] Check literals: infer type
- [ ] Check identifiers: lookup in scope
- [ ] Check binary: operand types compatible, infer result
- [ ] Check unary: operand type valid
- [ ] Check call: callee is function, arg types match
- [ ] Check field: struct has field
- [ ] Check index: indexable type, index is integer

#### 3.6 Testing
- [ ] Create `tests/type_checker_test.cot`
- [ ] Test valid programs pass
- [ ] Test type mismatches caught
- [ ] Test undefined variables caught
- [ ] Test function call arity/type errors

### Exit Criteria
- Rejects ill-typed programs with useful errors
- Accepts well-typed programs

---

## Phase 4: IR & Codegen (4-5 days)

**Goal:** Lower AST to IR, emit bytecode.

### Tasks

#### 4.1 IR Definitions (~400 lines)
- [ ] Create `src/ir.cot`
- [ ] Define `IrOp` enum
- [ ] Define `IrInstr` struct
- [ ] Define `IrFunction`, `IrBlock`, `IrModule`

#### 4.2 Lowerer Core (~400 lines)
- [ ] Create `src/lower.cot`
- [ ] Implement `Lowerer` struct
- [ ] Implement `lower(stmts)` → `IrModule`
- [ ] Implement temp allocation
- [ ] Implement label generation
- [ ] Implement local variable tracking

#### 4.3 Statement Lowering (~400 lines)
- [ ] Implement `lowerStmt(stmt)`
- [ ] Lower let/const to local allocation + init
- [ ] Lower function to IrFunction
- [ ] Lower if to conditional jumps
- [ ] Lower while/for to loop with jumps
- [ ] Lower return to Return instruction

#### 4.4 Expression Lowering (~400 lines)
- [ ] Implement `lowerExpr(expr)` → temp
- [ ] Lower literals to Const
- [ ] Lower identifiers to Load
- [ ] Lower binary to operation + temp
- [ ] Lower call to Call instruction
- [ ] Lower field to GetField
- [ ] Lower index to Index

#### 4.5 Bytecode Emitter (~800 lines)
- [ ] Create `src/emit.cot`
- [ ] Implement `Emitter` struct
- [ ] Implement `emit(module)` → BytecodeModule
- [ ] Implement opcode emission
- [ ] Implement constant pool
- [ ] Implement string interning
- [ ] Implement register allocation
- [ ] Implement jump patching

#### 4.6 Module Writer (~200 lines)
- [ ] Create `src/module.cot`
- [ ] Define BytecodeModule struct
- [ ] Implement `writeModule(module, path)`
- [ ] Write header (magic, version)
- [ ] Write constants section
- [ ] Write routines section
- [ ] Write code section

#### 4.7 Testing
- [ ] Create integration tests
- [ ] Compile simple programs
- [ ] Run with Zig VM
- [ ] Compare output with Zig-compiled version

### Exit Criteria
- Can compile simple Cot programs to working bytecode
- Produced bytecode runs correctly on VM

---

## Phase 5: Bootstrap (2-3 days)

**Goal:** Compiler compiles itself.

### Tasks

#### 5.1 Self-Compilation
- [ ] Compile entire compiler with Zig compiler → Stage 0
- [ ] Run Stage 0 to compile compiler → Stage 1
- [ ] Run Stage 1 to compile compiler → Stage 2
- [ ] Verify Stage 1 == Stage 2 (byte-for-byte)

#### 5.2 Bug Fixes
- [ ] Fix any issues preventing self-compilation
- [ ] May need multiple iterations

#### 5.3 Test Suite
- [ ] Run existing test suite with self-hosted compiler
- [ ] Verify all tests pass
- [ ] Compare output with Zig compiler output

#### 5.4 Documentation
- [ ] Document bootstrap process
- [ ] Document any Cot limitations discovered
- [ ] Update prerequisites based on findings

### Exit Criteria
- Compiler successfully compiles itself
- Bootstrap is reproducible
- All tests pass with self-hosted compiler

---

## Phase Summary

| Phase | Duration | Output |
|-------|----------|--------|
| 0: Prerequisites | 3-5 days | Verified Cot features |
| 1: Lexer | 2-3 days | Working tokenizer |
| 2: Parser | 5-7 days | Working parser + AST |
| 3: Type Checker | 4-5 days | Type validation |
| 4: IR & Codegen | 4-5 days | Bytecode generation |
| 5: Bootstrap | 2-3 days | Self-hosted compiler |
| **Total** | **20-28 days** | |

---

## Risk Mitigation

### Risk: Missing Cot Feature
**Mitigation:** Phase 0 identifies all gaps. Add features or workarounds before starting.

### Risk: Parser Complexity
**Mitigation:** Start with subset of syntax. Add features incrementally.

### Risk: Bytecode Incompatibility
**Mitigation:** Test each opcode against Zig compiler output.

### Risk: Performance
**Mitigation:** Not a priority for bootstrap. Optimize later.

### Risk: Bootstrap Fails
**Mitigation:** Keep Zig compiler as fallback. Debug incrementally.
