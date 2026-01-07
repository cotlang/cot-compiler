# Cot Compiler Architecture

## Overview

The self-hosted Cot compiler will follow a simplified version of the Zig compiler's architecture.

```
Source Code (.cot)
       ↓
    Lexer          → Token[]
       ↓
    Parser         → AST (NodeStore)
       ↓
  Type Checker     → Typed AST
       ↓
   IR Lowerer      → IR Module
       ↓
Bytecode Emitter   → Bytecode (.cbo)
```

---

## Directory Structure

```
~/cotlang/cot-compiler/
├── plan/                    # This planning documentation
├── src/
│   ├── main.cot             # Entry point, CLI
│   ├── lexer.cot            # Tokenizer
│   ├── token.cot            # Token types and structs
│   ├── parser.cot           # Parser (Pratt-based)
│   ├── ast.cot              # AST node definitions
│   ├── node_store.cot       # SoA AST storage
│   ├── types.cot            # Type system definitions
│   ├── type_checker.cot     # Type validation
│   ├── ir.cot               # IR definitions
│   ├── lower.cot            # AST → IR lowering
│   ├── emit.cot             # IR → Bytecode emission
│   ├── module.cot           # Bytecode module format
│   └── util/
│       ├── strings.cot      # String utilities
│       └── errors.cot       # Error handling
├── tests/
│   ├── prerequisites.cot    # Verify language features
│   ├── lexer_test.cot       # Lexer unit tests
│   ├── parser_test.cot      # Parser unit tests
│   └── integration/         # Full compilation tests
└── bootstrap/
    └── stage1.cbo           # First self-compiled binary
```

---

## Module Breakdown

### 1. Token Module (`token.cot`) ~100 lines

```cot
enum TokenType {
    // Literals
    Identifier,
    IntLiteral,
    FloatLiteral,
    StringLiteral,

    // Keywords
    Fn,
    Let,
    Const,
    If,
    Else,
    While,
    For,
    Return,
    Struct,
    Enum,
    Impl,
    Trait,

    // Operators
    Plus,
    Minus,
    Star,
    Slash,
    Equal,
    EqualEqual,
    BangEqual,
    Less,
    LessEqual,
    Greater,
    GreaterEqual,

    // Delimiters
    LeftParen,
    RightParen,
    LeftBrace,
    RightBrace,
    LeftBracket,
    RightBracket,
    Comma,
    Dot,
    Colon,
    Semicolon,
    Arrow,

    // Special
    Eof,
    Error,
}

struct Token {
    type: TokenType,
    text: string,
    line: i32,
    column: i32,
}

struct SourceLoc {
    line: i32,
    column: i32,
}
```

### 2. Lexer Module (`lexer.cot`) ~500 lines

```cot
struct Lexer {
    source: string,
    start: i64,
    current: i64,
    line: i32,
    column: i32,
}

impl Lexer {
    fn new(source: string) Lexer
    fn tokenize() []Token

    // Internal
    fn scanToken() Token
    fn advance() string
    fn peek() string
    fn peekNext() string
    fn isAtEnd() bool
    fn match(expected: string) bool
    fn skipWhitespace()
    fn scanString() Token
    fn scanNumber() Token
    fn scanIdentifier() Token
    fn makeToken(type: TokenType) Token
    fn errorToken(message: string) Token
}

// Character classification
fn isDigit(ch: string) bool
fn isAlpha(ch: string) bool
fn isAlphaNumeric(ch: string) bool
```

### 3. AST Module (`ast.cot`) ~400 lines

```cot
// Statement types
enum StmtKind {
    Expression,
    Let,
    Const,
    Return,
    If,
    While,
    For,
    Block,
    Function,
    Struct,
    Enum,
    Impl,
}

// Expression types
enum ExprKind {
    Literal,
    Identifier,
    Binary,
    Unary,
    Call,
    Index,
    Field,
    If,
    Block,
    Lambda,
    StructInit,
}

// Type reference types
enum TypeKind {
    Named,
    Pointer,
    Optional,
    Array,
    Slice,
    Function,
    Generic,
}

// Simplified AST nodes (not SoA initially)
struct Stmt {
    kind: StmtKind,
    loc: SourceLoc,
    // Fields for each kind...
    expr: ?*Expr,
    name: string,
    type_ref: ?*TypeRef,
    body: ?*Stmt,
    // etc.
}

struct Expr {
    kind: ExprKind,
    loc: SourceLoc,
    // Fields for each kind...
    literal_int: i64,
    literal_str: string,
    ident_name: string,
    binary_op: string,
    left: ?*Expr,
    right: ?*Expr,
    // etc.
}

struct TypeRef {
    kind: TypeKind,
    name: string,
    inner: ?*TypeRef,
    params: []TypeRef,
}
```

### 4. Parser Module (`parser.cot`) ~1500 lines

```cot
struct Parser {
    tokens: []Token,
    current: i64,
    errors: []ParseError,
}

impl Parser {
    fn new(tokens: []Token) Parser
    fn parse() []Stmt

    // Statements
    fn declaration() Stmt
    fn statement() Stmt
    fn letDeclaration() Stmt
    fn functionDeclaration() Stmt
    fn structDeclaration() Stmt
    fn enumDeclaration() Stmt
    fn implBlock() Stmt
    fn blockStatement() Stmt
    fn ifStatement() Stmt
    fn whileStatement() Stmt
    fn forStatement() Stmt
    fn returnStatement() Stmt
    fn expressionStatement() Stmt

    // Expressions (Pratt parsing)
    fn expression() Expr
    fn parsePrecedence(prec: Precedence) Expr
    fn unary() Expr
    fn binary(left: Expr) Expr
    fn call(callee: Expr) Expr
    fn index(obj: Expr) Expr
    fn field(obj: Expr) Expr
    fn primary() Expr
    fn literal() Expr
    fn identifier() Expr
    fn grouping() Expr
    fn ifExpression() Expr
    fn blockExpression() Expr
    fn lambda() Expr
    fn structInit() Expr

    // Types
    fn parseType() TypeRef

    // Utilities
    fn advance() Token
    fn peek() Token
    fn previous() Token
    fn check(type: TokenType) bool
    fn match(types: []TokenType) bool
    fn consume(type: TokenType, message: string) Token
    fn error(message: string)
    fn synchronize()
}

enum Precedence {
    None,
    Assignment,
    Or,
    And,
    Equality,
    Comparison,
    Term,
    Factor,
    Unary,
    Call,
    Primary,
}
```

### 5. Type System (`types.cot`) ~300 lines

```cot
enum TypeTag {
    Void,
    Bool,
    I8, I16, I32, I64,
    U8, U16, U32, U64,
    F32, F64,
    String,
    Decimal,
    Pointer,
    Optional,
    Array,
    Slice,
    Struct,
    Enum,
    Function,
    Trait,
}

struct Type {
    tag: TypeTag,
    name: string,

    // For compound types
    inner: ?*Type,           // Pointer, Optional, Array element
    fields: []Field,         // Struct fields
    variants: []Variant,     // Enum variants
    params: []Type,          // Function params
    return_type: ?*Type,     // Function return
}

struct Field {
    name: string,
    type: Type,
    offset: i32,
}

struct Variant {
    name: string,
    value: i64,
}
```

### 6. Type Checker (`type_checker.cot`) ~800 lines

```cot
struct TypeChecker {
    types: Map<string, Type>,
    functions: Map<string, FunctionSig>,
    scopes: []Scope,
}

struct Scope {
    variables: Map<string, Type>,
    parent: ?*Scope,
}

impl TypeChecker {
    fn new() TypeChecker
    fn check(stmts: []Stmt) []TypeError

    fn checkStmt(stmt: Stmt)
    fn checkExpr(expr: Expr) Type
    fn checkType(type_ref: TypeRef) Type

    fn enterScope()
    fn exitScope()
    fn define(name: string, type: Type)
    fn lookup(name: string) ?Type

    fn unify(expected: Type, actual: Type) bool
    fn isAssignable(target: Type, source: Type) bool
}
```

### 7. IR Module (`ir.cot`) ~400 lines

```cot
enum IrOp {
    // Constants
    Const,

    // Arithmetic
    Add, Sub, Mul, Div, Mod, Neg,

    // Comparison
    Eq, Ne, Lt, Le, Gt, Ge,

    // Logical
    And, Or, Not,

    // Control flow
    Jump, JumpIf, JumpIfNot,
    Call, Return,

    // Memory
    Load, Store,
    GetLocal, SetLocal,
    GetGlobal, SetGlobal,
    GetField, SetField,
    Index, IndexStore,

    // Allocation
    Alloc, Free,
}

struct IrInstr {
    op: IrOp,
    dest: i32,
    src1: i32,
    src2: i32,
    imm: i64,
    label: string,
}

struct IrFunction {
    name: string,
    params: []IrParam,
    return_type: Type,
    locals: []IrLocal,
    blocks: []IrBlock,
}

struct IrBlock {
    label: string,
    instrs: []IrInstr,
}

struct IrModule {
    functions: []IrFunction,
    globals: []IrGlobal,
    structs: []IrStruct,
}
```

### 8. IR Lowerer (`lower.cot`) ~1200 lines

```cot
struct Lowerer {
    module: IrModule,
    current_func: ?*IrFunction,
    current_block: ?*IrBlock,

    types: Map<string, Type>,
    locals: Map<string, i32>,
    local_count: i32,
    temp_count: i32,
    label_count: i32,
}

impl Lowerer {
    fn new() Lowerer
    fn lower(stmts: []Stmt) IrModule

    fn lowerStmt(stmt: Stmt)
    fn lowerExpr(expr: Expr) i32  // Returns temp/reg

    fn lowerFunction(stmt: Stmt)
    fn lowerStruct(stmt: Stmt)
    fn lowerLet(stmt: Stmt)
    fn lowerIf(stmt: Stmt)
    fn lowerWhile(stmt: Stmt)
    fn lowerReturn(stmt: Stmt)

    fn lowerBinary(expr: Expr) i32
    fn lowerUnary(expr: Expr) i32
    fn lowerCall(expr: Expr) i32
    fn lowerField(expr: Expr) i32
    fn lowerIndex(expr: Expr) i32

    fn emit(instr: IrInstr)
    fn newTemp() i32
    fn newLabel() string
    fn defineLocal(name: string) i32
    fn lookupLocal(name: string) ?i32
}
```

### 9. Bytecode Emitter (`emit.cot`) ~800 lines

```cot
struct Emitter {
    code: []u8,
    constants: []Constant,
    routines: []RoutineDef,

    string_pool: Map<string, i32>,
    int_pool: Map<i64, i32>,

    current_routine: ?*RoutineDef,
    register_map: Map<i32, i32>,
}

impl Emitter {
    fn new() Emitter
    fn emit(module: IrModule) BytecodeModule

    fn emitFunction(func: IrFunction)
    fn emitBlock(block: IrBlock)
    fn emitInstr(instr: IrInstr)

    fn emitOp(op: u8)
    fn emitByte(b: u8)
    fn emitU16(v: i32)
    fn emitU32(v: i32)

    fn addConstant(value: Constant) i32
    fn internString(s: string) i32
    fn internInt(i: i64) i32

    fn allocReg(temp: i32) i32
    fn freeReg(reg: i32)
}

struct BytecodeModule {
    magic: []u8,
    version_major: i32,
    version_minor: i32,
    code: []u8,
    constants: []Constant,
    routines: []RoutineDef,
}

fn writeModule(module: BytecodeModule, path: string)
```

### 10. Main Entry Point (`main.cot`) ~200 lines

```cot
fn main() {
    let args = get_args()

    if len(args) < 2 {
        println("Usage: cot-compiler <command> [options]")
        println("Commands:")
        println("  compile <file.cot> -o <output.cbo>")
        return
    }

    let command = args[1]

    match command {
        "compile" => {
            if len(args) < 3 {
                println("Error: missing input file")
                return
            }
            let input = args[2]
            let output = get_output_path(args)
            compile(input, output)
        }
        else => {
            println("Unknown command: ${command}")
        }
    }
}

fn compile(input: string, output: string) {
    println("Compiling ${input}...")

    // Read source
    let source = read_file(input)
    if source == null {
        println("Error: could not read ${input}")
        return
    }

    // Lexer
    let lexer = Lexer.new(source)
    let tokens = lexer.tokenize()
    println("  Lexed ${len(tokens)} tokens")

    // Parser
    let parser = Parser.new(tokens)
    let ast = parser.parse()
    if len(parser.errors) > 0 {
        for err in parser.errors {
            println("Parse error: ${err.message} at ${err.line}:${err.column}")
        }
        return
    }
    println("  Parsed ${len(ast)} statements")

    // Type check
    let checker = TypeChecker.new()
    let errors = checker.check(ast)
    if len(errors) > 0 {
        for err in errors {
            println("Type error: ${err.message}")
        }
        return
    }
    println("  Type check passed")

    // Lower to IR
    let lowerer = Lowerer.new()
    let ir = lowerer.lower(ast)
    println("  Generated IR")

    // Emit bytecode
    let emitter = Emitter.new()
    let module = emitter.emit(ir)
    println("  Emitted bytecode")

    // Write output
    writeModule(module, output)
    println("Wrote ${output}")
}
```

---

## Estimated Line Counts

| Module | Lines | Notes |
|--------|-------|-------|
| token.cot | 100 | Enums and structs |
| lexer.cot | 500 | Character processing |
| ast.cot | 400 | Node definitions |
| parser.cot | 1500 | Pratt parser |
| types.cot | 300 | Type definitions |
| type_checker.cot | 800 | Validation |
| ir.cot | 400 | IR definitions |
| lower.cot | 1200 | AST → IR |
| emit.cot | 800 | IR → Bytecode |
| main.cot | 200 | CLI |
| util/*.cot | 300 | Helpers |
| **Total** | **~6500** | |

---

## Simplifications from Zig Compiler

| Zig Feature | Cot Simplification |
|-------------|-------------------|
| SoA NodeStore | Simple struct per node (initially) |
| StringInterner | Use Map<string, id> |
| ArenaAllocator | ARC (automatic) |
| Packed structs | Regular structs |
| defer/errdefer | Explicit cleanup |
| Tagged unions | Struct with tag + fields |
| Comptime | Skip (runtime only) |
| Multiple error types | Single error struct |
| 145 opcodes | Start with ~50 core opcodes |

---

## Bootstrap Path

1. **Stage 0:** Use Zig compiler to compile cot-compiler
   ```bash
   cot compile src/main.cot -o bootstrap/cot-stage0.cbo
   ```

2. **Stage 1:** Use Stage 0 to compile itself
   ```bash
   cot run bootstrap/cot-stage0.cbo -- compile src/main.cot -o bootstrap/cot-stage1.cbo
   ```

3. **Stage 2:** Use Stage 1 to compile itself
   ```bash
   cot run bootstrap/cot-stage1.cbo -- compile src/main.cot -o bootstrap/cot-stage2.cbo
   ```

4. **Verify:** Stage 1 and Stage 2 should be identical
   ```bash
   diff bootstrap/cot-stage1.cbo bootstrap/cot-stage2.cbo
   # Should produce no output (files identical)
   ```
