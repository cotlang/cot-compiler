# Phi Node Implementation Plan

**Status:** ZIG IMPLEMENTATION COMPLETE - Self-hosted compiler port pending
**Goal:** Add proper SSA phi nodes to Cot IR to eliminate loop-related register allocation bugs

## Background

### The Problem
The current IR uses `alloca`/`store`/`load` patterns for loop variables. This requires the register allocator to understand control flow, which it doesn't do correctly for loop back-edges. Values that should survive across loop iterations get their registers clobbered.

### The Solution (from Go)
Go's compiler uses **phi nodes** to explicitly represent value merging at control flow join points:
```
loop_header:
    i = phi [(entry, 0), (incr, i_next)]
    end = phi [(entry, end_val), (incr, end)]  // loop-invariant
    cmp i < end
    brif body, exit
```

Phi nodes make value lifetimes explicit in the IR itself. The register allocator doesn't need to understand loops - phi nodes encode the semantics.

### Key Insight
A phi node says: "This value comes from different places depending on which predecessor block we came from." At a loop header:
- First iteration: value comes from loop entry (initial value)
- Subsequent iterations: value comes from loop body (updated value)

---

## Pre-Implementation Research

- [x] Read Go's `phi.go` - phi insertion algorithm (Braun et al. for small functions)
- [x] Read Go's `loopbce.go` - how Go represents induction variables with phi
- [x] Understand Go's `OpFwdRef` pattern for forward references
- [x] Understand dominance frontiers and where phi nodes are needed

---

## ZIG IMPLEMENTATION

### Phase 1: Add Phi Instruction to IR ✅

**File:** `src/ir/ir.zig`

- [x] Add `Phi` struct to instruction types:
```zig
pub const Phi = struct {
    result: Value,
    /// Array of (predecessor_block, value) pairs
    /// Length must match block.predecessors.len
    args: []PhiArg,

    pub const PhiArg = struct {
        block: *Block,
        value: Value,
    };
};
```

- [x] Add `.phi` variant to `Instruction` union
- [x] Update `Instruction.category()` - phi is `.control`
- [x] Update `Instruction.getResult()` - return phi.result
- [x] Update `Instruction.getOperands()` - return all phi arg values
- [x] Update `Instruction.hasSideEffects()` - false for phi (handled by default)
- [x] Update `verify.zig` - check phi arg values are defined
- [x] Update `type_checker.zig` - phi is type-safe by construction
- [x] Update `optimize.zig` - mark phi arg values as used
- [x] Update `printer.zig` - print phi nodes in IR dump

### Phase 2: Add Phi Construction Helpers

**File:** `src/ir/ir.zig` (Block struct)

- [ ] Add `Block.addPhi(result: Value, args: []PhiArg) !void`
- [ ] Add `Block.getPhis() []Instruction` - return all phi nodes (must be at block start)
- [ ] Add invariant: phi nodes must be first instructions in a block
- [ ] Add `Block.predecessors` population (currently exists but may need verification)

**File:** `src/ir/ir.zig` (Function struct)

- [ ] Add `Function.insertPhisForLoops() !void` - optional explicit phi insertion pass

### Phase 3: Update For-Loop IR Lowering

**File:** `src/ir/lower_stmt.zig`

This is the critical change. Replace the alloca/store/load pattern with phi nodes.

#### 3a: Remove Old Pattern (lowerFor - range iteration)
Current code (lines 884-996):
```zig
// OLD: Create alloca for loop variable
const loop_var = func.newValue(.{ .ptr = ty_ptr });
try l.emit(.{ .alloca = ... });

// OLD: Create alloca for end bound
const end_var = func.newValue(.{ .ptr = end_ty_ptr });
try l.emit(.{ .alloca = ... });

// OLD: Store initial values
try l.emit(.{ .store = .{ .ptr = loop_var, .value = start_val } });
try l.emit(.{ .store = .{ .ptr = end_var, .value = end_val } });

// OLD: In condition block, load values
try l.emit(.{ .load = .{ .ptr = loop_var, .result = current_val } });
try l.emit(.{ .load = .{ .ptr = end_var, .result = end_loaded } });
```

- [ ] Delete `loop_var` alloca creation
- [ ] Delete `end_var` alloca creation
- [ ] Delete all `store` instructions for loop variables
- [ ] Delete all `load` instructions for loop variables

#### 3b: Add Phi Node Pattern
New code:
```zig
// In entry block: compute start_val, end_val, then jump to cond

// In cond_block (loop header):
// Create phi for induction variable
const i_phi = func.newValue(.i64);
try l.emit(.{ .phi = .{
    .result = i_phi,
    .args = &.{
        .{ .block = entry_block, .value = start_val },
        .{ .block = incr_block, .value = i_next },  // forward ref, filled later
    },
}});

// Create phi for end bound (loop-invariant, but phi makes it explicit)
const end_phi = func.newValue(.i64);
try l.emit(.{ .phi = .{
    .result = end_phi,
    .args = &.{
        .{ .block = entry_block, .value = end_val },
        .{ .block = incr_block, .value = end_phi },  // self-reference (invariant)
    },
}});

// Use phi values directly in comparison
try l.emit(.{ .icmp = .{ .cond = cmp_cond, .lhs = i_phi, .rhs = end_phi, .result = cond_result } });

// In incr_block:
const i_next = func.newValue(.i64);
const one = func.newValue(.i64);
try l.emit(.{ .iconst = .{ .ty = .i64, .value = 1, .result = one } });
try l.emit(.{ .iadd = .{ .lhs = i_phi, .rhs = one, .result = i_next } });
// Now patch the phi to reference i_next
```

- [ ] Create `i_phi` value at cond_block start
- [ ] Create `end_phi` value at cond_block start (or optimize away if constant)
- [ ] Use phi values directly (no loads needed)
- [ ] Compute `i_next` in incr_block
- [ ] Implement forward reference patching for phi args

#### 3c: Update Collection Iteration (lowerCollectionIteration)
Same pattern for array/slice iteration (lines 1000-1180):

- [ ] Remove `len_var` alloca
- [ ] Remove `loop_var` alloca (already done above)
- [ ] Add phi for index variable
- [ ] Add phi for length (or hoist if loop-invariant)

#### 3d: Update Map Iteration (lowerMapIteration)
Similar changes for map iteration.

### Phase 4: Phi Elimination Pass (Before Bytecode Emission)

**New File:** `src/ir/phi_eliminate.zig`

Phi nodes don't exist in bytecode - they're an IR concept. Before emitting bytecode, we need to convert phi nodes to explicit moves along control flow edges.

```zig
/// Convert phi nodes to moves along predecessor edges
///
/// Before:
///   cond_block:
///     i = phi [(entry, 0), (incr, i_next)]
///
/// After:
///   entry_block:
///     i_entry = 0
///     jump cond_block
///   incr_block:
///     i_incr = i_next
///     jump cond_block
///   cond_block:
///     i = copy(predecessor's version)  // register allocator handles this
```

- [ ] Create `PhiEliminator` struct
- [ ] Implement `eliminatePhis(func: *ir.Function) !void`
- [ ] For each phi:
  - [ ] Create a "phi web" - all values that must be in same register
  - [ ] Insert copies at end of predecessor blocks
  - [ ] Replace phi with the appropriate incoming value
- [ ] Handle critical edges (may need edge splitting)

### Phase 5: Update Bytecode Emitter

**File:** `src/ir/emit_bytecode.zig`

- [ ] Add case for `.phi` instruction (after elimination, this shouldn't be reached)
- [ ] Or: call `phi_eliminate.eliminatePhis(func)` at start of `emitFunction`
- [ ] Remove old loop-variable-specific hacks if any exist
- [ ] Verify register allocator works with phi-eliminated code

### Phase 6: Remove Old Workarounds

**File:** `src/ir/lower_stmt.zig`

- [ ] Remove `_iter_idx` internal naming hack
- [ ] Remove `_loop_end` alloca pattern
- [ ] Remove `_array_len` alloca pattern
- [ ] Simplify scope handling for loop variables

**File:** `src/ir/emit_bytecode.zig`

- [ ] Remove any loop-specific register preservation logic
- [ ] Remove spill-on-loop-entry hacks if present

### Phase 7: Testing

- [ ] Unit test: phi node creation and serialization
- [ ] Unit test: phi elimination produces correct moves
- [ ] Integration test: `for i in 0..10` works
- [ ] Integration test: `for i in 0..len(array)` works (dynamic bound)
- [ ] Integration test: `for item in array` works
- [ ] Integration test: nested loops work
- [ ] Integration test: break/continue in loops work
- [ ] Regression test: string slice `text[0..1]` works

---

## SELF-HOSTED COMPILER (cot-compiler)

After Zig implementation is complete and tested, port to self-hosted compiler.

**File:** `~/cotlang/cot-compiler/src/ir.cot`

### Phase 1: Add Phi to IR Types

- [ ] Add `PhiArg` struct
- [ ] Add `Phi` struct
- [ ] Add `phi` variant to `Instruction` enum/union
- [ ] Update instruction helper methods

### Phase 2: Update IR Lowering

**File:** `~/cotlang/cot-compiler/src/lower.cot` (or equivalent)

- [ ] Port phi-based for-loop lowering from Zig
- [ ] Remove alloca/store/load pattern for loop variables

### Phase 3: Add Phi Elimination

**File:** `~/cotlang/cot-compiler/src/phi_eliminate.cot` (new)

- [ ] Port PhiEliminator from Zig
- [ ] Integrate into bytecode emission pipeline

### Phase 4: Update Bytecode Emitter

**File:** `~/cotlang/cot-compiler/src/emit.cot`

- [ ] Call phi elimination before emission
- [ ] Remove old loop workarounds

### Phase 5: Testing

- [ ] Self-hosted compiler builds successfully
- [ ] Self-hosted compiler can compile itself
- [ ] All loop tests pass

---

## RUST RUNTIME (cot-rs)

Phi nodes are an IR concept - they don't affect the VM or bytecode format. However, verify:

- [ ] No changes needed to `~/cotlang/cot-rs/src/value.rs`
- [ ] No changes needed to VM opcode handlers
- [ ] Bytecode format unchanged (phi elimination happens before emission)

If the phi elimination approach changes how we emit moves:
- [ ] Review `MOV` opcode handling
- [ ] Verify register-to-register copies work correctly

---

## Key Files Changed

### Zig Compiler
| File | Changes |
|------|---------|
| `src/ir/ir.zig` | Add Phi instruction, PhiArg struct |
| `src/ir/lower_stmt.zig` | Replace alloca/store/load with phi nodes |
| `src/ir/phi_eliminate.zig` | NEW - phi elimination pass |
| `src/ir/emit_bytecode.zig` | Call phi elimination, remove hacks |

### Self-Hosted Compiler
| File | Changes |
|------|---------|
| `src/ir.cot` | Add Phi types |
| `src/lower.cot` | Port phi-based lowering |
| `src/phi_eliminate.cot` | NEW - phi elimination |
| `src/emit.cot` | Integrate phi elimination |

### Rust Runtime
| File | Changes |
|------|---------|
| (none expected) | Verify no changes needed |

---

## Success Criteria

1. **Correctness**: All existing tests pass
2. **Loop bounds**: Dynamic loop bounds (e.g., `for i in 0..len(arr)`) work correctly
3. **No register corruption**: Values survive across loop iterations
4. **Clean IR**: No more alloca/store/load hacks for loop variables
5. **Self-hosting**: Self-hosted compiler works with new IR

---

## Notes

### Why Phi Elimination Instead of Direct Phi Bytecode?

Phi nodes are a compile-time concept. At runtime, we need actual register moves. The phi elimination pass converts the high-level "this value could come from here or there" into concrete "copy this value before jumping."

This is the standard approach used by LLVM, GCC, and Go.

### Forward References in Phi Args

When lowering a for-loop, the phi node for `i` needs to reference `i_next`, which isn't computed yet (it's in the incr block, which comes after cond). Options:
1. Use a placeholder value and patch later
2. Create all blocks first, then fill in instructions
3. Use a two-pass approach (create phi, then patch)

Go uses `OpFwdRef` placeholders. We'll use a similar approach.

### Loop-Invariant Values

For values like `end` that don't change across iterations, we still use a phi node:
```
end = phi [(entry, end_val), (incr, end)]  // self-reference
```

This makes the value flow explicit. An optimization pass could later recognize and hoist these, but correctness doesn't require it.

### Critical Edges

A critical edge is an edge from a block with multiple successors to a block with multiple predecessors. Phi elimination may need to split these edges to insert copies correctly. This is a well-known SSA concept.
