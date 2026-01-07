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

## Current Limitations

- ~~No heap allocation (`new`/`alloc`) - can't build full AST trees yet~~ **RESOLVED** - Use `List<T>` for dynamic collections
- ~~List<struct> loses fields~~ **RESOLVED** - StructBox and struct-aware opcodes added (2025-01-06)
- Parser validates syntax but doesn't store child nodes in AST (can now use `List<Node>` etc.)
