# Implementation Plan: Generic Type Support for Built-in Types

## Problem Statement

The self-hosted compiler's type checker cannot properly type-check code using generic types like `List<string>`. This blocks the driver from compiling because:

```cot
var args = process_args()  // Returns List<string>
var cmd = args.get(1)      // Type checker sees: i64.get(1) -> void
```

## Root Cause

1. **Builtin registration is incomplete** - `registerBuiltins()` only registers return type IDs, not full function signatures
2. **No generic type definitions** - `List<T>` is not registered in the TypeRegistry
3. **No method signatures for generics** - The type checker doesn't know `List<T>.get(i64)` returns `T`

## Required Changes

### 1. Register `List<T>` Generic Definition

**File:** `src/type_checker.cot` → `registerBuiltins()`

```cot
// Register List<T> generic type
var list_params = new List<string>
list_params.push("T")
const list_generic_id = regAddGenericType(self.reg, "List", list_params)
self.reg.generic_defs.set("List", list_generic_id)
```

### 2. Create `List<string>` Instance

```cot
// Create List<string> instance for process_args return type
var string_args = new List<i64>
string_args.push(self.reg.string_id)
const list_string_id = regAddGenericInstance(self.reg, "List", string_args)
```

### 3. Register List Method Signatures

**New section in type_checker.cot:**

```cot
// Register methods for List<T>
// List<T>.get(i64) -> T (element type)
// List<T>.len() -> i64
// List<T>.push(T) -> void
// List<T>.to_slice() -> []T

fn registerGenericMethods(self: TypeChecker) {
    // Store method signatures: "List.get" -> returns element type
    // Store method signatures: "List.len" -> returns i64
    self.method_returns.set("List.get", -2)   // -2 = element type placeholder
    self.method_returns.set("List.len", self.reg.i64_id)
    self.method_returns.set("List.push", self.reg.void_id)
}
```

### 4. Update Method Call Type Resolution

**File:** `src/type_checker.cot` → `checkMethodCall()` or equivalent

When resolving `obj.method()`:
1. Get type of `obj`
2. If type is a generic instance (e.g., `List<string>`):
   - Look up method signature for base type (e.g., `List.get`)
   - If return type is `-2` (element placeholder), return the generic argument type
   - Otherwise return the concrete return type

```cot
fn resolveMethodReturnType(self: TypeChecker, obj_type_id: i64, method_name: string) i64 {
    const obj_type = regGetType(self.reg, obj_type_id)

    // Check if this is a generic instance
    if (obj_type.tag == TypeTag.GenericType and obj_type.generic_arg_ids.len() > 0) {
        const base_name = obj_type.struct_name  // "List"
        const key = base_name + "." + method_name

        if (self.method_returns.has(key)) {
            const ret_type = self.method_returns.get(key)
            if (ret_type == -2) {
                // Return element type (first generic argument)
                return obj_type.generic_arg_ids.get(0)
            }
            return ret_type
        }
    }

    // Fall through to existing method resolution
    // ...
}
```

### 5. Create Proper Function Types for Builtins

Instead of just storing return type IDs, create full function types:

```cot
fn registerBuiltins(self: TypeChecker) {
    // Register List<T> generic
    self.registerListGeneric()

    // Create List<string> instance
    const list_string_id = self.createListInstance(self.reg.string_id)

    // process_args() -> List<string>
    var process_args_params = new List<i64>  // no params
    const process_args_fn_type = regAddFunctionType(self.reg, process_args_params, list_string_id)
    self.scopes.define("process_args", Symbol.init("process_args", SymbolKind.FunctionDef, process_args_fn_type, false, 0))

    // read_file(path: string) -> string
    var read_file_params = new List<i64>
    read_file_params.push(self.reg.string_id)
    const read_file_fn_type = regAddFunctionType(self.reg, read_file_params, self.reg.string_id)
    self.scopes.define("read_file", Symbol.init("read_file", SymbolKind.FunctionDef, read_file_fn_type, false, 0))

    // ... etc for other builtins
}
```

## Implementation Order

1. **Phase 1: Generic Type Infrastructure**
   - Add `registerListGeneric()` helper
   - Add `createListInstance(element_type_id)` helper
   - Register List generic and common instances (List<string>, List<i64>)

2. **Phase 2: Method Signatures**
   - Add method signature storage for generic types
   - Implement `resolveMethodReturnType()` with generic support

3. **Phase 3: Builtin Functions**
   - Update `registerBuiltins()` to use proper function types
   - Register all native functions with full signatures

4. **Phase 4: Integration**
   - Update call expression type checking to use new infrastructure
   - Test with driver.cot

## Files to Modify

| File | Changes |
|------|---------|
| `src/type_checker.cot` | Add generic registration, method resolution, builtin updates |
| `src/types.cot` | Possibly add helper functions for generic type operations |

## Testing

1. Compile driver.cot - should pass type checking
2. Verify `args.get(1)` returns `string` type
3. Verify `args.len()` returns `i64` type
4. Run driver with simple test file
