# Cot Self-Hosted Compiler Guidelines

## Cot Code Style

### Control Flow
- **Always use `switch`** when matching discrete values (integers, enums, strings)
- Only use `if/else if` for:
  - Range checks (`x > 5 and x < 10`)
  - Complex boolean conditions that can't be switch cases
  - Single condition checks

### Examples

**Good:**
```cot
switch (token.token_type) {
    TokenType.Plus => { return Precedence.PrecTerm }
    TokenType.Star => { return Precedence.PrecFactor }
}
```

**Bad:**
```cot
if (token.token_type == TokenType.Plus) {
    return Precedence.PrecTerm
} else if (token.token_type == TokenType.Star) {
    return Precedence.PrecFactor
}
```

### Naming
- Functions: `camelCase` (e.g., `parseExpr`, `lexerAdvance`)
- Types/Structs/Enums: `PascalCase` (e.g., `TokenType`, `Parser`)
- Variables: `snake_case` (e.g., `token_type`, `param_count`)

### Structure
- Group related functions with comment headers
- Keep constructors near their related parsing functions
- Use early returns to reduce nesting

## Project Structure

```
src/
├── token.cot    # Token types and helpers
├── lexer.cot    # Tokenizer
├── ast.cot      # AST node definitions
└── parser.cot   # Parser (Pratt parser for expressions)
```

## Compiling

```bash
cd ~/cotlang/cot-compiler
cot compile src/parser.cot -o /tmp/parser.cbo
```

## Current Status

### Completed
- ~~No heap allocation (`new`/`alloc`)~~ **RESOLVED** - Use `List<T>` for dynamic collections
- ~~List<struct> loses fields~~ **RESOLVED** - StructBox and struct-aware opcodes added (2025-01-06)
- ~~Static method syntax broken~~ **RESOLVED** - `Type.method()` calls now work (2026-01-08)
  - Fixed in Zig compiler: `src/ir/lower_expr.zig` - check `fn_return_types` not `module.functions`
- ~~type_checker.cot uses old patterns~~ **RESOLVED** - Converted to impl blocks, switch statements (2026-01-08)
- ~~Parser AST population~~ **RESOLVED** - All AST child nodes now properly populated (2026-01-08)
  - All 16 expression makers, 7 type parsers, 18 statement makers working
  - Uses `new T{...}` heap allocation and `List.to_slice()` for collections
  - Integration test passes: binary/unary exprs, method calls, structs, switches, loops, defer

### Idiomatic Redesign: COMPLETE (2026-01-08)

All phases of `plan/11-idiomatic-redesign.md` are complete:
- ✅ Phase 1: token.cot - impl blocks for TokenType, Token
- ✅ Phase 2: lexer.cot - impl blocks for Lexer
- ✅ Phase 3: ast.cot - impl blocks, traits defined, arena allocation
- ✅ Phase 4: parser.cot - impl blocks, AST population
- ✅ Phase 5: type_checker.cot - impl blocks, visitor pattern
- ✅ Phase 6: All files compile successfully
- ✅ `impl Trait for Type` syntax works correctly
- ✅ `str()` function added as alias for `string()`
