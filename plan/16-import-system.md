# Import System Implementation Plan

**Goal:** Enable multi-file compilation in cot-compiler to support self-hosting.

## Current State

### What Exists
- **Parser**: `parseImportStmt()` parses `import "module"` syntax ✅
- **AST**: `StmtKind.ImportStmt` with `import_path` field ✅
- **Type Checker**: Empty handler `StmtKind.ImportStmt => {}` ❌
- **Driver**: Single-file only, no import processing ❌
- **Built-ins**: `read_file(path: string) -> string` available ✅

### What's Missing
1. Module resolution (path → file)
2. Module loading and caching
3. Symbol export/import mechanism
4. Dependency ordering
5. Cycle detection
6. Combined module output

---

## Design Decisions

### Import Semantics

```cot
import "token"           // Import from search path: ./token.cot
import "std/list"        // Import from std library: std/list.cot
import "./utils"         // Relative import: ./utils.cot
import "../common/types" // Parent-relative: ../common/types.cot
```

### Export Model: Everything Public by Default
- All top-level declarations are exported (simple, like Go)
- Future: Add `private` keyword for non-exported items

### Module Identity
- Module path is the canonical identifier
- `import "token"` and `import "./token"` resolve to same module
- Each module compiled exactly once (cached)

---

## Implementation Phases

## Phase 1: Module Infrastructure (~200 lines)

Create `src/module.cot` with core data structures:

```cot
// Module represents a compiled module
struct Module {
    path: string,           // Canonical path (e.g., "token", "./utils")
    source_path: string,    // File system path (e.g., "/path/to/token.cot")
    ast: *ParsedModule,     // Parsed AST (from parser)
    exports: Map<string, Symbol>, // Exported symbols
    imports: List<string>,  // Modules this depends on
    is_loaded: bool,        // True after type checking
}

// ModuleCache manages all loaded modules
struct ModuleCache {
    modules: Map<string, *Module>,  // path -> Module
    search_paths: List<string>,     // Directories to search
    current_file: string,           // For relative imports
}

impl ModuleCache {
    fn create(base_path: string) ModuleCache
    fn resolve(self: *ModuleCache, import_path: string) ?string  // Returns file path
    fn get(self: *ModuleCache, path: string) ?*Module
    fn add(self: *ModuleCache, mod: *Module)
}
```

**Files to modify:** None (new file)

---

## Phase 2: Module Resolution (~100 lines)

Implement path resolution in `module.cot`:

```cot
impl ModuleCache {
    // Resolve import path to file system path
    fn resolve(self: *ModuleCache, import_path: string) ?string {
        // 1. Check if relative path
        if (import_path.starts_with("./") or import_path.starts_with("../")) {
            // Resolve relative to current file's directory
            var dir = dirname(self.current_file)
            var full_path = join_path(dir, import_path + ".cot")
            if (file_exists(full_path)) {
                return full_path
            }
            return null
        }

        // 2. Search in search paths
        var i: i64 = 0
        while (i < self.search_paths.len()) {
            var search_dir = self.search_paths.get(i)
            var full_path = join_path(search_dir, import_path + ".cot")
            if (file_exists(full_path)) {
                return full_path
            }
            i += 1
        }

        return null
    }
}

// Helper: Get directory from file path
fn dirname(path: string) string {
    var i = len(path) - 1
    while (i >= 0) {
        if (path[i] == '/') {
            return path[0..i]
        }
        i -= 1
    }
    return "."
}

// Helper: Join path components
fn join_path(dir: string, file: string) string {
    if (len(dir) == 0 or dir == ".") {
        return file
    }
    return dir + "/" + file
}
```

**Dependencies:** Need `file_exists(path: string) -> bool` built-in or implement via `read_file`

---

## Phase 3: Module Loading (~150 lines)

Add module loading to `module.cot`:

```cot
impl ModuleCache {
    // Load a module (parse + cache, but don't type check yet)
    fn load(self: *ModuleCache, import_path: string) ?*Module {
        // Check cache first
        var cached = self.modules.get(import_path)
        if (cached != null) {
            return cached
        }

        // Resolve to file path
        var file_path = self.resolve(import_path)
        if (file_path == null) {
            return null  // Module not found
        }

        // Read and parse
        var source = read_file(file_path)
        if (len(source) == 0) {
            return null  // Could not read
        }

        // Save current file, set new one for nested imports
        var prev_file = self.current_file
        self.current_file = file_path

        // Parse
        var parser = Parser.create(source)
        var parsed = parser.parseModule()

        // Restore current file
        self.current_file = prev_file

        if (parsed.has_errors) {
            return null  // Parse errors
        }

        // Create module
        var mod = new Module {
            path = import_path,
            source_path = file_path,
            ast = parsed,
            exports = Map<string, Symbol>.create(),
            imports = List<string>.create(),
            is_loaded = false,
        }

        // Extract import dependencies
        var i: i64 = 0
        while (i < parsed.statements.len()) {
            var stmt = parsed.statements.get(i)
            if (stmt.kind == StmtKind.ImportStmt) {
                mod.imports.push(stmt.import_path)
            }
            i += 1
        }

        // Cache it
        self.modules.set(import_path, mod)

        return mod
    }
}
```

---

## Phase 4: Dependency Ordering (~100 lines)

Topological sort for compile order:

```cot
// Get modules in dependency order (dependencies first)
fn getCompileOrder(cache: *ModuleCache, root_path: string) List<string> {
    var result = List<string>.create()
    var visited = Map<string, bool>.create()
    var in_progress = Map<string, bool>.create()

    fn visit(path: string) bool {
        if (visited.get(path) == true) {
            return true  // Already processed
        }
        if (in_progress.get(path) == true) {
            // Cycle detected!
            println("Error: Import cycle detected involving: " + path)
            return false
        }

        in_progress.set(path, true)

        var mod = cache.get(path)
        if (mod == null) {
            return false
        }

        // Visit dependencies first
        var i: i64 = 0
        while (i < mod.imports.len()) {
            var dep = mod.imports.get(i)
            if (!visit(dep)) {
                return false
            }
            i += 1
        }

        in_progress.set(path, false)
        visited.set(path, true)
        result.push(path)
        return true
    }

    visit(root_path)
    return result
}
```

---

## Phase 5: Type Checker Integration (~200 lines)

Modify `type_checker.cot` to handle imports:

```cot
// Add to TypeChecker struct:
struct TypeChecker {
    // ... existing fields ...
    module_cache: *ModuleCache,  // NEW
    current_module: string,      // NEW
}

// Modify typeCheck to accept module cache:
fn typeCheck(stmts: []Stmt, cache: *ModuleCache, module_path: string) TypeChecker {
    var tc = TypeChecker {
        // ... existing init ...
        module_cache = cache,
        current_module = module_path,
    }

    // Process statements
    var i: i64 = 0
    while (i < len(stmts)) {
        tc.checkStmt(stmts[i])
        i += 1
    }

    return tc
}

// Update ImportStmt handler:
impl TypeChecker {
    fn checkImportStmt(self: *TypeChecker, stmt: *Stmt) {
        var import_path = stmt.import_path

        // Get the imported module (already loaded)
        var mod = self.module_cache.get(import_path)
        if (mod == null) {
            self.error("Module not found: " + import_path, stmt.loc.line)
            return
        }

        // Import all exported symbols into current scope
        var keys = mod.exports.keys()
        var i: i64 = 0
        while (i < keys.len()) {
            var name = keys.get(i)
            var symbol = mod.exports.get(name)

            // Check for conflicts
            if (self.scopes.lookup(name) != null) {
                self.error("Import conflict: '" + name + "' already defined", stmt.loc.line)
            } else {
                self.scopes.define(name, symbol)
            }
            i += 1
        }
    }
}
```

---

## Phase 6: Export Collection (~100 lines)

After type checking a module, collect its exports:

```cot
// Add to TypeChecker:
impl TypeChecker {
    // Collect exports after type checking
    fn collectExports(self: *TypeChecker) Map<string, Symbol> {
        var exports = Map<string, Symbol>.create()

        // Get all symbols from the module scope (top-level only)
        var symbols = self.scopes.getModuleScope()
        var keys = symbols.keys()

        var i: i64 = 0
        while (i < keys.len()) {
            var name = keys.get(i)
            var sym = symbols.get(name)

            // Export declarations (not built-ins)
            if (sym.kind == SymbolKind.FunctionDef or
                sym.kind == SymbolKind.StructDef or
                sym.kind == SymbolKind.EnumDef or
                sym.kind == SymbolKind.TraitDef or
                sym.kind == SymbolKind.TypeAliasDef or
                sym.kind == SymbolKind.Constant) {

                // Skip built-ins (defined at line 0)
                if (sym.decl_line > 0) {
                    exports.set(name, sym)
                }
            }
            i += 1
        }

        return exports
    }
}
```

---

## Phase 7: Driver Integration (~150 lines)

Modify `driver.cot` for multi-file compilation:

```cot
fn main() i64 {
    // ... parse args ...

    // Create module cache with search paths
    var cache = ModuleCache.create(dirname(source_file))
    cache.search_paths.push(dirname(source_file))  // Current directory
    cache.search_paths.push(".")                    // Working directory

    // Phase 1: Load all modules (parse only)
    println("[driver] === Phase 1: Loading Modules ===")
    var root_mod = cache.load(source_file)
    if (root_mod == null) {
        println("[driver] Error: Could not load " + source_file)
        return 1
    }

    // Recursively load all dependencies
    if (!loadDependencies(cache, root_mod)) {
        return 1
    }

    // Phase 2: Get compile order (topological sort)
    var order = getCompileOrder(cache, source_file)
    println("[driver]   Compile order: " + string(order.len()) + " modules")

    // Phase 3: Type check in dependency order
    println("[driver]")
    println("[driver] === Phase 2: Type Checking ===")
    var i: i64 = 0
    while (i < order.len()) {
        var path = order.get(i)
        var mod = cache.get(path)

        println("[driver]   Type checking: " + path)
        var tc = typeCheck(mod.ast.statements.to_slice(), cache, path)

        if (tc.had_error) {
            // Print errors...
            return 1
        }

        // Collect exports
        mod.exports = tc.collectExports()
        mod.is_loaded = true

        i += 1
    }

    // Phase 4: Lower all modules
    println("[driver]")
    println("[driver] === Phase 3: Lowering ===")
    var lowerer = newLowerer(tc.reg)

    i = 0
    while (i < order.len()) {
        var path = order.get(i)
        var mod = cache.get(path)
        lowerModule(lowerer, mod.ast.statements.to_slice())
        i += 1
    }

    // Phase 5: Emit combined bytecode
    // ... existing emit code ...
}

fn loadDependencies(cache: *ModuleCache, mod: *Module) bool {
    var i: i64 = 0
    while (i < mod.imports.len()) {
        var dep_path = mod.imports.get(i)

        // Load if not cached
        if (cache.get(dep_path) == null) {
            var dep = cache.load(dep_path)
            if (dep == null) {
                println("[driver] Error: Could not load: " + dep_path)
                return false
            }
            // Recursively load its dependencies
            if (!loadDependencies(cache, dep)) {
                return false
            }
        }
        i += 1
    }
    return true
}
```

---

## Phase 8: Testing (~50 lines)

Create test files:

**test/imports/main.cot:**
```cot
import "helper"

fn main() i64 {
    var x = helperAdd(10, 20)
    println(string(x))
    return 0
}
```

**test/imports/helper.cot:**
```cot
fn helperAdd(a: i64, b: i64) i64 {
    return a + b
}
```

**Test command:**
```bash
cot compile test/imports/main.cot -o test.cbo
cot run test.cbo  # Should print 30
```

---

## File Summary

| File | Action | Lines |
|------|--------|-------|
| `src/module.cot` | NEW | ~400 |
| `src/type_checker.cot` | MODIFY | ~100 |
| `src/driver.cot` | MODIFY | ~100 |
| **Total** | | ~600 |

---

## Implementation Order

1. **Day 1**: Phase 1-2 (Module infrastructure + resolution)
   - Create `module.cot` with ModuleCache, Module structs
   - Implement path resolution logic
   - Test: Can resolve `import "token"` to `token.cot`

2. **Day 2**: Phase 3-4 (Loading + dependency ordering)
   - Implement module loading with parsing
   - Implement topological sort
   - Test: Load multi-file project, detect cycles

3. **Day 3**: Phase 5-6 (Type checker integration)
   - Add module_cache to TypeChecker
   - Implement ImportStmt handling
   - Implement export collection
   - Test: Type check with imported symbols

4. **Day 4**: Phase 7-8 (Driver + testing)
   - Update driver for multi-file compilation
   - Create test cases
   - Test: End-to-end multi-file compilation

---

## Dependencies

### Built-ins Needed
- `read_file(path: string) -> string` ✅ (exists)
- `file_exists(path: string) -> bool` ❌ (need to add or emulate)

**Workaround for file_exists:**
```cot
fn file_exists(path: string) bool {
    var content = read_file(path)
    return len(content) > 0
}
```
Note: This can't distinguish "empty file" from "file not found" - acceptable for MVP.

### Runtime Requirements
- `Map<K, V>` with `.keys()` method
- String slicing and comparison

---

## Success Criteria

1. ✅ `import "module"` loads and type-checks the module
2. ✅ Symbols from imported module are available
3. ✅ Circular imports are detected with clear error
4. ✅ Multiple files compile to single bytecode output
5. ✅ Can compile cot-compiler itself (16 source files)

---

## Future Enhancements (Not in Scope)

- `import "module" as alias` - aliased imports
- `from "module" import {a, b}` - selective imports
- `private fn foo()` - visibility modifiers
- Package/project configuration file
- Standard library path configuration
