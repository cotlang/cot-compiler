# Language Prerequisites

Before starting the self-hosted compiler, these Cot features must be verified or implemented.

---

## P0: BLOCKING (Must Have Before Starting)

### 1. Character Access in Strings

**Need:** Get character at index for lexer
```cot
let ch = char_at(source, i)  // returns single character as string or i32
if ch == '"' { ... }
```

**Test:**
```cot
fn test_char_at() {
    let s = "hello"
    assert(char_at(s, 0) == "h")
    assert(char_at(s, 4) == "o")
}
```

**Implementation:** Native function `char_at(str: string, index: i64) string`

**Status:** [ ] Needs verification/implementation

---

### 2. Dynamic Array (List)

**Need:** Growable array for tokens, AST nodes
```cot
var tokens: []Token = []
tokens.push(Token { ... })
let count = len(tokens)
let first = tokens[0]
```

**Alternative Syntax:**
```cot
var tokens = List<Token>.new()
tokens.append(Token { ... })
```

**Test:**
```cot
fn test_dynamic_array() {
    var arr: []i64 = []
    arr.push(1)
    arr.push(2)
    arr.push(3)
    assert(len(arr) == 3)
    assert(arr[0] == 1)
    assert(arr[2] == 3)
}
```

**Status:** [ ] Needs verification - may need `array_push` native

---

### 3. Self-Referential Struct

**Need:** AST nodes that reference other AST nodes
```cot
struct Expr {
    kind: ExprKind,
    left: ?*Expr,   // optional pointer to another Expr
    right: ?*Expr,
}
```

**Test:**
```cot
fn test_self_ref() {
    var inner = Expr { kind: ExprKind.Literal, left: null, right: null }
    var outer = Expr { kind: ExprKind.Binary, left: &inner, right: null }
    assert(outer.left != null)
}
```

**Status:** [ ] Needs verification

---

### 4. Map with String Keys

**Need:** Symbol tables, identifier lookup
```cot
var symbols = Map<string, Symbol>.new()
symbols["x"] = Symbol { ... }
let sym = symbols["x"]
let exists = "x" in symbols  // or symbols.has("x")
```

**Test:**
```cot
fn test_string_map() {
    var map = Map<string, i64>.new()
    map["a"] = 1
    map["b"] = 2
    assert(map["a"] == 1)
    assert(map.has("b"))
    assert(!map.has("c"))
}
```

**Status:** [ ] Needs verification of method syntax

---

### 5. Enum Comparison in Match

**Need:** Dispatch on token type, AST node type
```cot
enum TokenType {
    Identifier,
    Number,
    String,
    Plus,
    Minus,
}

fn process(t: TokenType) {
    match t {
        TokenType.Identifier => println("id")
        TokenType.Number => println("num")
        else => println("other")
    }
}
```

**Test:**
```cot
fn test_enum_match() {
    let t = TokenType.Number
    var result = ""
    match t {
        TokenType.Identifier => result = "id"
        TokenType.Number => result = "num"
        else => result = "other"
    }
    assert(result == "num")
}
```

**Status:** [ ] Needs verification

---

### 6. Struct Method Calls

**Need:** Methods on Token, Lexer, Parser structs
```cot
struct Lexer {
    source: string,
    pos: i64,
}

impl Lexer {
    fn new(source: string) Lexer {
        return Lexer { source: source, pos: 0 }
    }

    fn peek(self: Lexer) string {
        return char_at(self.source, self.pos)
    }

    fn advance(self: *Lexer) {
        self.pos = self.pos + 1
    }
}
```

**Test:**
```cot
fn test_methods() {
    var lex = Lexer.new("hello")
    assert(lex.peek() == "h")
    lex.advance()
    assert(lex.peek() == "e")
}
```

**Status:** [ ] Needs verification of mutable self

---

### 7. String Comparison

**Need:** Compare strings for keywords, operators
```cot
if text == "fn" { ... }
if text == "let" { ... }
```

**Test:**
```cot
fn test_string_compare() {
    let a = "hello"
    let b = "hello"
    let c = "world"
    assert(a == b)
    assert(a != c)
}
```

**Status:** [x] Should work - verify

---

### 8. String Length

**Need:** Check bounds in lexer
```cot
let length = len(source)
while pos < length { ... }
```

**Status:** [x] `len()` exists - verify works on strings

---

## P1: IMPORTANT (Need During Development)

### 9. Optional Unwrapping

**Need:** Safe access to nullable values
```cot
let maybeToken: ?Token = lexer.peek()
if let token = maybeToken {
    // token is unwrapped Token here
}
```

**Alternative:**
```cot
if maybeToken != null {
    let token = maybeToken!  // force unwrap
}
```

**Status:** [ ] Needs verification

---

### 10. String Slicing

**Need:** Extract substrings for token text
```cot
let text = substring(source, start, end - start)
// or
let text = source[start:end]
```

**Status:** [x] `substring()` exists - verify

---

### 11. Integer to String

**Need:** Error messages with line numbers
```cot
let msg = "Error at line " + string(line)
// or
let msg = "Error at line ${line}"
```

**Status:** [x] Interpolation exists - verify

---

### 12. Character Code Comparison

**Need:** Check character ranges (digits, letters)
```cot
fn is_digit(ch: string) bool {
    let code = ascii(ch)
    return code >= 48 and code <= 57  // '0' to '9'
}
```

**Alternative:** String comparison
```cot
fn is_digit(ch: string) bool {
    return ch >= "0" and ch <= "9"
}
```

**Status:** [ ] Needs verification of string ordering

---

### 13. Array Iteration

**Need:** Process all tokens
```cot
for token in tokens {
    process(token)
}
```

**Status:** [x] Should work - verify

---

### 14. Struct Initialization

**Need:** Create AST nodes
```cot
let node = BinaryExpr {
    op: "+",
    left: leftExpr,
    right: rightExpr,
}
```

**Status:** [x] Should work - verify

---

## P2: NICE TO HAVE (Can Work Around)

### 15. Tagged Union / Sum Type

**Want:**
```cot
enum Expr {
    Literal(i64),
    Binary(string, Expr, Expr),
    Unary(string, Expr),
}
```

**Workaround:**
```cot
enum ExprKind { Literal, Binary, Unary }

struct Expr {
    kind: ExprKind,
    literal_value: i64,
    binary_op: string,
    left: ?*Expr,
    right: ?*Expr,
    unary_op: string,
    operand: ?*Expr,
}
```

**Status:** [ ] Nice to have but not blocking

---

### 16. String Builder

**Want:**
```cot
var sb = StringBuilder.new()
sb.append("error: ")
sb.append(message)
sb.append(" at line ")
sb.append(string(line))
let result = sb.build()
```

**Workaround:**
```cot
let result = "error: ${message} at line ${line}"
```

**Status:** [ ] Workaround acceptable

---

### 17. File Line Reading

**Want:**
```cot
let lines = read_lines(path)
for line in lines { ... }
```

**Workaround:**
```cot
let content = read_file(path)
// Process character by character
```

**Status:** [ ] Workaround acceptable

---

## VERIFICATION CHECKLIST

Create file `~/cotlang/cot-compiler/tests/prerequisites.cot`:

```cot
// Test all prerequisites before starting compiler

fn test_char_at() {
    let s = "hello"
    println("char_at test...")
    assert(char_at(s, 0) == "h", "char_at failed")
    println("  PASS")
}

fn test_dynamic_array() {
    println("dynamic array test...")
    var arr: []i64 = []
    // arr.push(1) or array_push(arr, 1)
    println("  TODO: implement")
}

fn test_self_ref_struct() {
    println("self-ref struct test...")
    // TODO
    println("  TODO: implement")
}

fn test_map_methods() {
    println("map methods test...")
    var map = Map<string, i64>.new()
    map["key"] = 42
    assert(map["key"] == 42, "map get failed")
    println("  PASS")
}

fn test_enum_match() {
    println("enum match test...")
    // TODO
    println("  TODO: implement")
}

fn test_struct_methods() {
    println("struct methods test...")
    // TODO
    println("  PASS")
}

fn main() {
    println("=== Cot Compiler Prerequisites ===")
    test_char_at()
    test_dynamic_array()
    test_self_ref_struct()
    test_map_methods()
    test_enum_match()
    test_struct_methods()
    println("=== All tests complete ===")
}
```

---

## IMPLEMENTATION PRIORITY

### Week 1: Core Prerequisites
1. [ ] `char_at(str, i)` native function
2. [ ] Dynamic array push/append
3. [ ] Verify Map<string, T> methods
4. [ ] Verify enum match syntax
5. [ ] Verify struct method with mutable self

### Week 1-2: Secondary Prerequisites
6. [ ] Verify optional unwrapping
7. [ ] Verify string ordering comparison
8. [ ] Create prerequisite test suite

### After Prerequisites Pass
- Begin Lexer implementation
