# Idiomatic Cot Compiler Redesign

**Created:** 2026-01-08
**Status:** COMPLETED (2026-01-08)
**Goal:** Make cot-compiler use more Cot language features as dogfooding

## Progress (2026-01-08)

- ✅ **Zig Compiler Bug Fixed:** `Type.method()` static call syntax now works
  - Fixed `src/ir/lower_expr.zig` to check `fn_return_types` (populated in impl_sigs phase)
  - Previously checked `module.functions` which is only populated in impl_bodies phase
- ✅ **type_checker.cot:** Refactored to use impl blocks
  - Symbol, TraitDef, ScopeManager, TypeChecker all have impl blocks
  - Uses `ScopeManager.init()`, `Symbol.invalid()` static method calls
  - Converted if/else chains to switch statements for StmtKind/ExprKind
- ✅ **lexer.cot, token.cot, types.cot:** Already using idiomatic patterns
  - All compile successfully
- ✅ **Parser AST Population:** All AST child nodes properly populated
  - See `plan/10-parser-ast-fix.md` (marked COMPLETED)
  - Uses `new T{...}` heap allocation and `List.to_slice()` for collections
  - All 16 expression makers, 7 type parsers, 18 statement makers working
  - Integration test passes: binary/unary exprs, method calls, structs, switches, loops, defer
- ✅ **ast.cot:** Arena allocation infrastructure added
  - `allocExpr()`, `allocStmt()`, `allocTypeRef()` available
  - `clearArenas()` and `arenaStats()` helpers
- ✅ **All files compile:** token.cot, lexer.cot, ast.cot, parser.cot, type_checker.cot, types.cot

## Status: All Features Working (2026-01-08)

**`impl Trait for Type` works correctly!** The original failure was due to using `str()` instead of `string()`.

**Fix Applied:** Added `str()` as an alias for `string()` in both runtimes:
- Zig: `src/runtime/native/conversion.zig`
- Rust: `cot-rs/src/native/convert.rs`

All idiomatic Cot patterns are now fully functional:
- `impl Type { ... }` - instance methods
- `impl Trait for Type { ... }` - trait implementations
- Static method calls `Type.method()`
- String interpolation `"${value}"`
- `str()` / `string()` for value-to-string conversion

## Philosophy

The self-hosted compiler should be a showcase of idiomatic Cot code. Every Cot language feature should be used where appropriate, both to test the feature and to demonstrate best practices.

## Features to Use Extensively

### 1. Impl Blocks (Methods)
Convert all `moduleFunctionName(ptr, ...)` to `ptr.method(...)` style.

**Before:**
```cot
fn lexerAdvance(lexer: *Lexer) string { ... }
fn lexerPeek(lexer: *Lexer) string { ... }
lexerAdvance(&lex)
```

**After:**
```cot
impl Lexer {
    fn advance(self: *Lexer) string { ... }
    fn peek(self: *Lexer) string { ... }
}
lex.advance()
```

### 2. Traits
Define common behaviors as traits.

```cot
trait Display {
    fn display(self) string;
}

trait Visitor<T> {
    fn visitExpr(self: *Self, expr: *Expr) T;
    fn visitStmt(self: *Self, stmt: *Stmt) T;
}

impl Display for Token {
    fn display(self: Token) string {
        return self.token_type.name() + ":" + self.lexeme
    }
}
```

### 3. Enum Methods
Add methods to enums for common operations.

**Before:**
```cot
fn isKeyword(t: TokenType) bool { ... }
fn isOperator(t: TokenType) bool { ... }
```

**After:**
```cot
impl TokenType {
    fn isKeyword(self: TokenType) bool { ... }
    fn isOperator(self: TokenType) bool { ... }
    fn name(self: TokenType) string { ... }
    fn precedence(self: TokenType) i64 { ... }
}
```

### 4. Optional Chaining and Null Coalescing
Use `?.` and `??` throughout.

```cot
// Instead of:
if (expr.left != null) {
    var left_str = expr.left.display()
}

// Use:
var left_str = expr.left?.display() ?? "<none>"
```

### 5. Defer for Cleanup
```cot
fn parseBlock(self: *Parser) *Stmt {
    self.pushScope()
    defer self.popScope()

    // ... parsing code ...
    // Scope automatically popped on any exit
}
```

### 6. Lambdas for Visitors
```cot
fn mapExprs(exprs: List<*Expr>, transform: fn(*Expr) -> *Expr) List<*Expr> {
    var result = new List<*Expr>
    for expr in exprs {
        result.push(transform(expr))
    }
    return result
}

// Usage
var transformed = mapExprs(node.args, |e| { return simplifyExpr(e) })
```

### 7. Error Handling with try/catch
```cot
fn parse(source: string) ?Module {
    try {
        var parser = Parser.new(source)
        return parser.parseModule()
    } catch (err) {
        println("Parse error: " + err)
        return null
    }
}
```

---

## Refactoring Plan

### Phase 1: token.cot (Estimated: 30 min)

1. Add `impl TokenType` block with methods:
   - `isKeyword(self: TokenType) bool`
   - `isOperator(self: TokenType) bool`
   - `isLiteral(self: TokenType) bool`
   - `name(self: TokenType) string` - human-readable name
   - `precedence(self: TokenType) i64` - for Pratt parser

2. Add `Display` trait and implement for Token

3. Move `newToken` into `impl Token` as `Token.new(...)`

### Phase 2: lexer.cot (Estimated: 45 min)

1. Convert all `lexerXxx(lexer: *Lexer)` functions to methods:
   - `advance(self: *Lexer) string`
   - `peek(self: *Lexer) string`
   - `peekNext(self: *Lexer) string`
   - `match(self: *Lexer, expected: string) bool`
   - `skipWhitespace(self: *Lexer)`
   - `scanToken(self: *Lexer) Token`
   - etc.

2. Add static constructor: `Lexer.new(source: string) Lexer`

3. Use `defer` for any cleanup needed

### Phase 3: ast.cot (Estimated: 1 hour)

1. Add traits:
   ```cot
   trait ASTNode {
       fn loc(self) SourceLoc;
       fn kind(self) string;
   }

   trait Display {
       fn display(self) string;
   }
   ```

2. Implement traits for Expr, Stmt, TypeRef

3. Add `impl` blocks with constructors and helper methods:
   ```cot
   impl Expr {
       fn new(kind: ExprKind, loc: SourceLoc) Expr { ... }
       fn binary(op: TokenType, left: *Expr, right: *Expr, loc: SourceLoc) *Expr { ... }
       fn unary(op: TokenType, operand: *Expr, loc: SourceLoc) *Expr { ... }
       fn call(callee: *Expr, args: List<*Expr>, loc: SourceLoc) *Expr { ... }
       // ... etc
   }
   ```

4. Add arena allocation as module-level with methods:
   ```cot
   var g_expr_arena: List<Expr> = new List<Expr>

   fn allocExpr(e: Expr) *Expr {
       g_expr_arena.push(e)
       return g_expr_arena.lastPtr()  // Need to add this method
   }
   ```

5. Add methods to ExprKind and StmtKind enums

### Phase 4: parser.cot (Estimated: 2 hours)

1. Convert to method-based design:
   ```cot
   impl Parser {
       fn new(source: string) Parser { ... }
       fn advance(self: *Parser) { ... }
       fn check(self: *Parser, tt: TokenType) bool { ... }
       fn match(self: *Parser, tt: TokenType) bool { ... }
       fn consume(self: *Parser, tt: TokenType, msg: string) { ... }
       fn parseModule(self: *Parser) Module { ... }
       fn parseStatement(self: *Parser) *Stmt { ... }
       fn parseExpression(self: *Parser) *Expr { ... }
       // ... etc
   }
   ```

2. Fix all 41 TODOs for AST population (from plan/10-parser-ast-fix.md)

3. Use optional chaining where appropriate

4. Add proper error recovery with try/catch

### Phase 5: type_checker.cot (Estimated: 1 hour)

1. Implement as trait-based visitor:
   ```cot
   impl TypeChecker {
       fn check(self: *TypeChecker, module: *Module) bool { ... }
       fn checkExpr(self: *TypeChecker, expr: *Expr) Type { ... }
       fn checkStmt(self: *TypeChecker, stmt: *Stmt) { ... }
   }
   ```

2. Use Map for symbol tables with proper scoping

### Phase 6: Integration and Testing (Estimated: 1 hour)

1. Update driver.cot to use new APIs
2. Verify all features work
3. Add comprehensive test cases

---

## Detailed Changes by File

### token.cot Changes

```cot
// Add impl block for TokenType
impl TokenType {
    fn isKeyword(self: TokenType) bool {
        return self >= TokenType.KwFn and self <= TokenType.KwTest
    }

    fn isOperator(self: TokenType) bool {
        switch (self) {
            TokenType.Plus, TokenType.Minus, TokenType.Star, TokenType.Slash,
            TokenType.EqualEqual, TokenType.BangEqual,
            TokenType.Less, TokenType.LessEqual,
            TokenType.Greater, TokenType.GreaterEqual => { return true }
            else => { return false }
        }
    }

    fn name(self: TokenType) string {
        switch (self) {
            TokenType.Plus => { return "+" }
            TokenType.Minus => { return "-" }
            TokenType.Star => { return "*" }
            // ... etc
        }
    }
}

// Add impl block for Token
impl Token {
    fn new(token_type: TokenType, lexeme: string, line: i64, column: i64, start: i64, end: i64) Token {
        return Token{
            .token_type = token_type,
            .lexeme = lexeme,
            .line = line,
            .column = column,
            .span = Span{ .start = start, .end = end },
        }
    }
}

// Add Display trait
trait Display {
    fn display(self) string;
}

impl Display for Token {
    fn display(self: Token) string {
        return self.token_type.name() + "(" + self.lexeme + ")"
    }
}
```

---

## Success Criteria

1. All functions converted to methods where appropriate
2. Traits defined and used for common behaviors
3. Optional chaining (`?.`) used instead of null checks
4. Null coalescing (`??`) used for defaults
5. defer used for cleanup/scope management
6. try/catch used for error handling
7. All 41 parser TODOs resolved
8. Code compiles and passes tests
9. Code demonstrates idiomatic Cot patterns

---

## Risks and Mitigations

1. **Enum method syntax**: Verify enum impl blocks work correctly
   - Mitigation: Test with simple examples first

2. **Trait object dispatch**: Ensure dyn Trait works
   - Mitigation: May need to use concrete types initially

3. **Self-referential types**: AST nodes reference each other
   - Mitigation: Already works with `?*T` pointers

4. **List pointer stability**: Arena allocation pointer validity
   - Mitigation: Don't reallocate during traversal
