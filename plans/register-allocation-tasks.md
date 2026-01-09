# Register Allocation Implementation Tasks

**Parent Plan:** `register-allocation-redesign.md`
**Status:** Zig Implementation COMPLETE, Self-Hosted Compiler PENDING

## Pre-Implementation Research (COMPLETED)

- [x] Read Go's `regalloc.go` - understand core data structures
- [x] Read Go's `use` struct - distance tracking
- [x] Read Go's `valState` - per-value state
- [x] Read Go's `regState` - per-register state
- [x] Read Go's `allocReg` - farthest-next-use spilling
- [x] Read Go's `allocValToReg` - value-to-register allocation
- [x] Read Go's `advanceUses` - use advancement and freeing
- [x] Read Go's `computeLive` - liveness analysis

## ZIG IMPLEMENTATION (COMPLETED 2026-01-09)

### Phase 1: Core Data Structures ✅
- [x] Define `Use` struct with `dist: u32`, `next: ?*Use` in `regalloc.zig:42`
- [x] Implement use list pool (avoid allocations during processing)
- [x] Define `ValueState` struct in `regalloc.zig:57`
- [x] Define `RegState` struct in `regalloc.zig:90`
- [x] Create `RegAllocState` struct in `regalloc.zig:100`

### Phase 2: Use Distance Computation ✅
- [x] Implement `computeUseDistances(func)` in `regalloc.zig:193`
- [x] Implement `addUse(value_id, dist)` in `regalloc.zig:256`
- [x] Handle constants and locals

### Phase 3: Register Allocation Core ✅
- [x] Implement `freeReg(r)` in `regalloc.zig:306`
- [x] Implement `spillReg(r)` in `regalloc.zig:341`
- [x] Implement `allocReg(mask)` in `regalloc.zig:363`
- [x] Implement `assignReg(value_id, r)` in `regalloc.zig:406`
- [x] Implement helper methods: `getRegister`, `getSpillSlot`, `setSpillSlot`, `getRegValue`

### Phase 4: BytecodeEmitter Integration ✅
- [x] Add `reg_state: regalloc.RegAllocState` field to BytecodeEmitter
- [x] Update `emitFunction` to call `reg_state.computeUseDistances(func)`
- [x] Update `getValueInRegById` to use reg_state
- [x] Update `getValueInReg` to use reg_state
- [x] Update `prepareDestReg` to use reg_state
- [x] Update `setLastResult` to use reg_state
- [x] Update `allocateWithSpill` to use reg_state
- [x] Update `selectSpillCandidate` to use reg_state
- [x] Update `emit_instruction.zig` references

### Phase 5: Remove Old Code ✅
- [x] Delete `RegisterAllocator` struct from emit_bytecode.zig
- [x] Delete `reg_alloc` field
- [x] Delete `spilled_values` field
- [x] Update all `reg_alloc.*` calls to `reg_state.*`
- [x] Update all `spilled_values.*` calls to `reg_state.*` methods

### Phase 6: Testing ✅
- [x] Build succeeds with no compilation errors
- [x] String slice test passes: `text[0..1]` returns "h"
- [x] Self-hosted compiler ready for integration

---

## SELF-HOSTED COMPILER (PENDING)

The Zig implementation is now complete and serves as the reference. The self-hosted compiler at `~/cotlang/cot-compiler/src/emit.cot` needs the same changes.

### Current State in emit.cot
- Has old `RegisterAllocator` struct (lines 355-375)
- Has old `regAllocAllocate`, `regAllocGetRegister`, `regAllocFree` functions
- Missing: Use distance tracking, ValueState, farthest-next-use spilling

### Tasks for Self-Hosted Implementation

#### Phase 1: Core Data Structures
- [ ] Add `Use` struct in emit.cot
- [ ] Add `ValueState` struct in emit.cot
- [ ] Add `RegState` struct in emit.cot
- [ ] Add `RegAllocState` struct replacing old RegisterAllocator

#### Phase 2: Use Distance Computation
- [ ] Implement `regStateComputeUseDistances(ra, func)`
- [ ] Implement `regStateAddUse(ra, value_id, dist)`

#### Phase 3: Register Allocation Core
- [ ] Implement `regStateFreeReg(ra, r)`
- [ ] Implement `regStateSpillReg(ra, r)`
- [ ] Implement `regStateAllocReg(ra, mask)` with farthest-next-use
- [ ] Implement `regStateAssignReg(ra, value_id, r)`
- [ ] Implement helper methods

#### Phase 4: BytecodeEmitter Integration
- [ ] Replace `reg_alloc` field with new `reg_state`
- [ ] Update all function calls

#### Phase 5: Remove Old Code
- [ ] Remove old RegisterAllocator struct and functions
- [ ] Remove old helper functions

#### Phase 6: Testing
- [ ] Compile self-hosted compiler
- [ ] Run self-hosted compiler tests

## Notes

### Key Files Changed (Zig)
- `src/ir/regalloc.zig` - New Go-style register allocator
- `src/ir/emit_bytecode.zig` - Removed old RegisterAllocator, integrated reg_state
- `src/ir/emit_instruction.zig` - Updated spilled_values and reg_alloc references

### Key Insight
The single source of truth for register state is now `reg_state`. This prevents the dual-allocator bugs that caused register corruption in string slice operations.
