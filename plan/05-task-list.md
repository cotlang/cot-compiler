# Detailed Task List

## Status Legend
- [ ] Not started
- [~] In progress
- [x] Complete
- [!] Blocked

---

## PHASE 0: PREREQUISITES

### 0.1 Environment Setup
- [x] Create directory structure: `~/cotlang/cot-compiler/src/`
- [x] Create directory structure: `~/cotlang/cot-compiler/tests/`
- [ ] Create directory structure: `~/cotlang/cot-compiler/bootstrap/`

### 0.2 Feature Verification Tests
**Status: COMPLETE** - See `06-prerequisites-status.md` for details.

All critical features verified working:
- [x] Character/substring access via slice syntax
- [x] Array indexing
- [x] Enum IR lowering
- [x] Map.has() and Map.delete()
- [x] impl block method dispatch
- [x] switch statement with enums
- [x] Self-referential structs

### 0.3 Missing Feature Implementation
- [x] All P0 blockers fixed

### 0.4 Documentation
- [x] Create `06-prerequisites-status.md`
- [x] Document all verified working patterns

---

## PHASE 1: LEXER

### 1.1 Token Module

#### File: `src/token.cot` - COMPLETE
- [x] Define TokenType enum (75+ variants)
- [x] Define Token struct
- [x] Define SourceLoc struct
- [x] Define Span struct with impl block
- [x] Helper: `newToken()` function
- [x] Helper: `isKeyword()` function
- [x] Helper: `isOperator()` function
- [x] Helper: `isLiteral()` function

### 1.2 Lexer Core

#### File: `src/lexer.cot` - COMPLETE
- [x] Define Lexer struct
- [x] Implement `newLexer(source: string) Lexer`
- [x] Implement `lexerIsAtEnd(lexer: *Lexer) bool`
- [x] Implement `lexerAdvance(lexer: *Lexer) string`
- [x] Implement `lexerPeek(lexer: *Lexer) string`
- [x] Implement `lexerPeekNext(lexer: *Lexer) string`
- [x] Implement `lexerMatch(lexer: *Lexer, expected: string) bool`

### 1.3 Token Scanning - COMPLETE
- [x] Implement `lexerScanToken(lexer: *Lexer) Token`
- [x] Implement `lexerSkipWhitespace(lexer: *Lexer)`
  - [x] Skip spaces, tabs, newlines
  - [x] Skip line comments `//`
  - [x] Skip block comments `/* */`
- [x] Implement `lexerScanString(lexer: *Lexer) Token`
- [x] Implement `lexerScanNumber(lexer: *Lexer) Token`
  - [x] Integer literals
  - [x] Decimal literals with decimal point
  - [x] Hex literals: 0x...
  - [x] Binary literals: 0b...
- [x] Implement `lexerScanIdentifier(lexer: *Lexer) Token`
- [x] Implement `lexerMakeToken(lexer: *Lexer, token_type: TokenType) Token`
- [x] Implement `lexerErrorToken(lexer: *Lexer, message: string) Token`

### 1.4 Character Helpers - COMPLETE
- [x] Implement `isDigit(ch: string) bool`
- [x] Implement `isAlpha(ch: string) bool`
- [x] Implement `isAlphaNumeric(ch: string) bool`
- [x] Implement `isHexDigit(ch: string) bool`

### 1.5 Keyword Table - COMPLETE
- [x] Implement `identifierType(text: string) TokenType`
- [x] All keywords mapped (35+ keywords)

### 1.6 Lexer Tests - COMPLETE
- [x] Test file: `tests/lexer_test.cot`
- [x] Tests run and pass

### 1.7 Code Quality Improvements - COMPLETE
- [x] Refactor deeply nested if chains using `else if`
- [x] Refactor keyword lookup using `switch` on strings (lines 416-468)
- [x] Refactor character matching using `switch` on strings (lines 254-392)

**Language features verified working:**
1. ✅ `else if` keyword - works
2. ✅ `switch` on strings - works

---

## PHASE 2: PARSER

### 2.1 AST Module - COMPLETE
- [x] Define StmtKind enum (18 variants)
- [x] Define ExprKind enum (18 variants)
- [x] Define TypeKind enum (8 variants)
- [x] Define Stmt, Expr, TypeRef structs
- [x] Define supporting structs (Param, Field, FieldInit, EnumVariant, SwitchArm)
- [x] Define SourceLoc struct and helper functions

### 2.2 Parser Core - COMPLETE
- [x] Define Parser struct (lexer, current, previous, error flags)
- [x] Implement parser initialization (newParser)
- [x] Implement token navigation (advance, peek, check, match, consume)
- [x] Implement error handling and synchronization
- [x] Implement precedence enum and getInfixPrecedence
- [x] Implement parseInt, parseHex, parseBinary utilities

### 2.3 Expression Parsing (Pratt Parser) - COMPLETE
- [x] Implement precedence enum and getInfixPrecedence
- [x] Implement parseExpr (entry point)
- [x] Implement parseExprPrec with precedence (Pratt parser)
- [x] Implement parsePrimaryExpr (literals, identifiers, grouping, unary ops)
- [x] Implement makeBinaryExpr, makeUnaryExpr, make*Expr constructors
- [x] Implement precToInt/intToPrec helpers for precedence comparison
- [x] Implement parseCallExpr (function calls)
- [x] Implement parseIndexExpr (array/slice indexing)
- [x] Implement parseFieldExpr (field access)
- [x] Implement makeCallExpr, makeFieldExpr, makeIndexExpr constructors

### 2.4 Statement Parsing - COMPLETE
- [x] Implement parseStatement (dispatch by keyword)
- [x] Implement parseVarDecl
- [x] Implement parseConstDecl
- [x] Implement parseReturnStmt
- [x] Implement parseIfStmt
- [x] Implement parseWhileStmt
- [x] Implement parseForStmt
- [x] Implement parseBlock
- [x] Implement parseSwitchStmt
- [x] Implement parseExpressionStmt
- [x] Implement statement constructors (makeExprStmt, makeVarDeclStmt, etc.)

### 2.5 Declaration Parsing - COMPLETE
- [x] Implement parseFunctionDecl
- [x] Implement parseStructDecl
- [x] Implement parseEnumDecl
- [x] Implement parseImplDecl
- [x] Implement parseImport

### 2.6 Type Parsing - COMPLETE
- [x] Implement parseType
- [x] Handle pointer types (*T)
- [x] Handle optional types (?T)
- [x] Handle array types ([N]T)
- [x] Handle slice types ([]T)
- [x] Handle function types
- [x] Handle generic types (T[U])

### 2.7 Parser Tests
- [!] Test file: tests/parser_test.cot (created, blocked by cache bug)

### 2.8 Zig Lexer/Parser Parity Enhancements
- [x] String interpolation lexing/parsing (StringInterpStart, StringContent, etc.)
- [x] pub keyword handling (parsePubDecl)
- [x] View declaration parsing (parseViewDecl)
- [x] Escape sequence handling fix in Zig lexer (scanString)
- [x] Trait declaration parsing (parseTraitDecl)
- [x] Comptime statement parsing (parseComptimeStmt, parseComptimeIf)

---

## PHASE 3-5: See original task list

---

## IMMEDIATE PRIORITIES

1. ~~**Language Enhancement: `else if`**~~ ✅ DONE
2. ~~**Language Enhancement: `switch` on strings**~~ ✅ DONE
3. ~~**Refactor lexer.cot**~~ ✅ DONE (already uses switch on strings)
4. ~~**Phase 2.1: AST Module**~~ ✅ DONE (`src/ast.cot`)
5. ~~**Phase 2.2: Parser Core**~~ ✅ DONE (`src/parser.cot`)
6. ~~**Phase 2.3: Expression Parsing**~~ ✅ DONE - Pratt parser with all expression types
7. ~~**Phase 2.4: Statement Parsing**~~ ✅ DONE - var/const, if, while, for, switch, block
8. ~~**Phase 2.5: Declaration Parsing**~~ ✅ DONE - fn, struct, enum, impl, import
9. ~~**Phase 2.6: Type Parsing**~~ ✅ DONE - Named, pointer, optional, array, slice, generic, function
10. **Phase 2.7: Parser Tests** - Create test file
11. **Phase 3: Type Checker** - In Progress (see below)
12. **Phase 4: IR Module** - Not Started (CRITICAL - largest component)
13. **Phase 5: Bytecode Emission** - Not Started
14. **Phase 6: Bootstrap** - Not Started

---

## PHASE 3: TYPE SYSTEM (COMPLETE)

### 3.1 Type Registry (`types.cot`) - 880 lines
- [x] TypeKind enum (including GenericType, GenericParam)
- [x] TypeRegistry struct
- [x] Primitive type registration
- [x] Type lookup by ID
- [x] Pointer type construction (regAddPointerType)
- [x] Optional type construction (regAddOptionalType)
- [x] Array/Slice type construction (regAddArrayType, regAddSliceType)
- [x] Function type construction (regAddFunctionType)
- [x] Struct/Enum registration with fields
- [x] Type compatibility checking (isAssignableToById)
- [x] Generic type support (regAddGenericType, regAddGenericInstance)
- [x] Type equality checking (typesEqualById)

### 3.2 Type Checker (`type_checker.cot`) - 1,565 lines
- [x] Basic expression type inference
- [x] Binary operation type checking
- [x] Function call type checking
- [x] Struct field access
- [x] Variable declaration checking
- [x] All 20 statement kinds handled
- [x] Generic type resolution (tcResolveGenericType)
- [x] Trait method signature tracking (TraitMethodSig, TraitDef)
- [x] Impl block trait validation (tcValidateTraitImpl)
- [ ] Exhaustive switch checking (optional polish)
- [ ] Return type verification for all paths (optional polish)

---

## PHASE 4: IR MODULE (NOT STARTED - CRITICAL)

**Reference:** Zig IR module is ~16,879 lines. Target: ~8,000-10,000 Cot lines.

### 4.1 IR Representation (`ir.cot`)
- [ ] IR.Type - type representation
- [ ] IR.Value - value with type and ID
- [ ] IR.Instruction - all IR operations (~50 instruction types)
- [ ] IR.BasicBlock - control flow blocks
- [ ] IR.Function - function container
- [ ] IR.Module - top-level module

### 4.2 AST to IR Lowering (`lower.cot`)
- [ ] lowerModule(ast) -> IR.Module
- [ ] lowerFunction(fn_decl) -> IR.Function
- [ ] lowerStatement(stmt) - all statement types
- [ ] lowerExpression(expr) - all expression types

### 4.3 Scope Management (`scope.cot`)
- [ ] Scope stack for nested blocks
- [ ] Variable lookup chain
- [ ] Shadowing support

### 4.4 Closure Handling (`closure.cot`)
- [ ] Free variable detection
- [ ] Environment capture

---

## PHASE 5: BYTECODE EMISSION (NOT STARTED)

**Reference:** Zig emit module is ~3,500 lines. Target: ~3,000-4,000 Cot lines.

### 5.1 Bytecode Format (`bytecode.cot`)
- [ ] Module format (magic, version, sections)
- [ ] Constant pool
- [ ] Function table
- [ ] Opcode definitions (~150 opcodes)

### 5.2 Code Emission (`emit.cot`)
- [ ] IR to bytecode translation
- [ ] Register allocation
- [ ] Label resolution
- [ ] Binary writer

---

## PHASE 6: BOOTSTRAP (NOT STARTED)

- [ ] Self-compile all compiler modules
- [ ] Verify output matches Zig-compiled version
- [ ] Run test suite with self-compiled compiler

---

## PROGRESS SUMMARY (REVISED)

| Phase | Status | Cot Lines | Zig Reference |
|-------|--------|-----------|---------------|
| Phase 0: Prerequisites | ✅ COMPLETE | - | - |
| Phase 1: Lexer | ✅ COMPLETE | 471 | ~1,000 |
| Phase 2: Parser | ✅ COMPLETE | 1,469 | ~3,131 |
| Phase 3: Type System | ✅ COMPLETE | 2,445 | ~2,211 |
| Phase 4: IR Module | ❌ NOT STARTED | 0 | ~16,879 |
| Phase 5: Bytecode Emit | ❌ NOT STARTED | 0 | ~3,500 |
| Phase 6: Bootstrap | ❌ NOT STARTED | 0 | - |
| **Total** | | **~4,385** | **~26,721** |

**Current progress: ~16% of compiler code (excluding VM/runtime)**

### Phase 3 Completion Summary
- **types.cot**: 880 lines (40% over Zig reference due to more verbose syntax)
- **type_checker.cot**: 1,565 lines (71% of Zig reference)
- **Key features added**: Generic type instantiation, trait method signature tracking, impl validation

See `08-detailed-requirements.md` for comprehensive breakdown.

## COMPILER BUGS FIXED (This Session)

1. **Null coercion to optional types** - `?void` (null literal) now coerces to any optional type
2. **Empty slice coercion** - `void` (empty array `[]`) now coerces to any slice type
3. **Type equality comparison** - Added `typesEqual()` for semantic comparison (by name/structure, not pointer identity)
4. **Large struct return overflow** - Fixed integer overflow when returning structs with >16 fields
5. **List<struct> field loss** - Structs stored in List lost non-first fields. Fixed by adding StructBox type and struct-aware list opcodes (list_push_struct, list_get_struct, list_pop_struct, list_set_struct) in both Zig and Rust runtimes
