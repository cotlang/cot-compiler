# Register Allocation Redesign Plan

**Status:** Planning
**Created:** 2026-01-09
**Goal:** Replace ad-hoc register allocation with Go-style linear scan allocator

## Problem Statement

The current bytecode emitter allocates registers ad-hoc during instruction emission:
- `getValueInReg(value, temp_reg)` tries to load a value into a suggested register
- When loading heap field pointers, it picks `struct_ptr_reg = 0 or 1` arbitrarily
- There's no knowledge of which registers will be needed for subsequent operands
- Spill decisions are based on "what's currently in the register" not "what will be needed soonest"

This causes register corruption bugs:
1. Load source string into r0 (uses r1 for struct pointer)
2. Load start index into r1 (uses r0 for struct pointer, clobbers source!)
3. str_slice now has wrong values in registers

## Go's Approach (from `cmd/compile/internal/ssa/regalloc.go`)

Go uses a **linear scan register allocator** with these key properties:

### Data Structures

```go
// Distance to next use for each value
type use struct {
    dist int32   // distance from start of block to use
    pos  src.XPos
    next *use    // linked list in nondecreasing dist order
}

// Per-value state
type valState struct {
    regs  regMask  // which registers hold this value
    uses  *use     // list of upcoming uses
    spill *Value   // spilled copy if any
}

// Per-register state
type regState struct {
    v *Value  // original value in this register
    c *Value  // current copy of value (might be v or a copy)
}
```

### Algorithm Overview

1. **Pre-pass: Compute use distances**
   - Walk backwards through each block
   - For each instruction, record distance to next use for each operand
   - This builds a linked list of uses per value

2. **Main pass: Process instructions forward**
   - For each instruction:
     a. Load all input operands into registers (`allocValToReg`)
     b. If no free register: spill value with **farthest next use**
     c. After instruction: advance use pointers, free dead values
     d. Allocate output register

3. **Key insight: Spill farthest-next-use**
   ```go
   // Find register to spill - pick the one used furthest in future
   var r register
   maxuse := int32(-1)
   for t := register(0); t < s.numRegs; t++ {
       if mask>>t&1 == 0 { continue }
       v := s.regs[t].v
       if n := s.values[v.ID].uses.dist; n > maxuse {
           r = t
           maxuse = n
       }
   }
   ```

## Implementation Plan for Cot

### Phase 1: Data Structures

Create new file `src/ir/regalloc.zig` with:

```zig
/// Distance to next use for a value
pub const Use = struct {
    dist: u32,      // distance from current instruction
    next: ?*Use,    // linked list
};

/// Per-value allocation state
pub const ValueState = struct {
    regs: u16,          // bitmask of registers holding this value (0 = not in any)
    uses: ?*Use,        // linked list of upcoming uses
    spill_slot: ?u16,   // stack slot if spilled
    needs_reg: bool,    // does this value need a register?
    is_const: bool,     // is this a constant (can rematerialize)?
    const_idx: ?u16,    // constant pool index if const
    local_slot: ?u16,   // local slot if from alloca
};

/// Per-register state
pub const RegState = struct {
    value_id: ?u32,     // value currently in this register (null = free)
    dirty: bool,        // has been modified since load?
};

/// Main allocator state
pub const RegAllocState = struct {
    allocator: Allocator,

    // Per-value state (indexed by value_id)
    values: []ValueState,

    // Per-register state (16 registers)
    regs: [16]RegState,

    // Bitmask of used registers
    used: u16,

    // Bitmask of registers that can't be spilled (holding nospill values)
    nospill: u16,

    // Free list for Use structs (avoid allocation during processing)
    free_uses: ?*Use,

    // Current instruction index
    cur_idx: u32,

    // Spill slot allocation
    next_spill_slot: u16,
    spill_slot_base: u16,
};
```

### Phase 2: Use Distance Computation

Add function to compute use distances by walking backwards:

```zig
/// Compute use distances for all values in a function.
/// Must be called before processing instructions.
pub fn computeUseDistances(self: *RegAllocState, func: *const ir.Function) !void {
    // Walk backwards through all blocks
    for (func.blocks.items) |block| {
        var dist: u32 = @intCast(block.instructions.items.len);

        // Walk backwards through instructions
        var i = block.instructions.items.len;
        while (i > 0) {
            i -= 1;
            dist -= 1;
            const inst = block.instructions.items[i];

            // Record uses of operands
            for (inst.getOperands()) |operand| {
                try self.addUse(operand.id, dist);
            }
        }
    }
}

fn addUse(self: *RegAllocState, value_id: u32, dist: u32) !void {
    // Get or allocate a Use struct
    const use = if (self.free_uses) |u| blk: {
        self.free_uses = u.next;
        break :blk u;
    } else try self.allocator.create(Use);

    use.* = .{ .dist = dist, .next = self.values[value_id].uses };
    self.values[value_id].uses = use;
}
```

### Phase 3: Register Allocation Core

```zig
/// Allocate a register from the given mask.
/// If all registers are used, spills the one with farthest next use.
pub fn allocReg(self: *RegAllocState, mask: u16) !u4 {
    const available = mask & ~self.used;

    if (available != 0) {
        // Free register available
        const r = @ctz(available);
        self.used |= @as(u16, 1) << r;
        return @intCast(r);
    }

    // No free register - find one to spill
    // Spill the value with farthest next use
    var best_reg: ?u4 = null;
    var best_dist: u32 = 0;

    for (0..16) |r| {
        if (mask >> @intCast(r) & 1 == 0) continue;
        if (self.nospill >> @intCast(r) & 1 != 0) continue;

        const value_id = self.regs[r].value_id orelse continue;
        const dist = if (self.values[value_id].uses) |u| u.dist else std.math.maxInt(u32);

        if (dist > best_dist) {
            best_dist = dist;
            best_reg = @intCast(r);
        }
    }

    const r = best_reg orelse return error.NoRegisterAvailable;
    try self.spillReg(r);
    self.used |= @as(u16, 1) << r;
    return r;
}

/// Get a value into a register (from the given mask).
/// Returns the register containing the value.
pub fn allocValToReg(self: *RegAllocState, value_id: u32, mask: u16) !u4 {
    const vs = &self.values[value_id];

    // Check if already in a suitable register
    if (vs.regs & mask != 0) {
        return @ctz(vs.regs & mask);
    }

    // Need to load into a register
    const r = try self.allocReg(mask);

    // Load the value
    if (vs.spill_slot) |slot| {
        // Load from spill slot
        try self.emitSpillLoad(r, slot);
    } else if (vs.is_const) {
        // Load constant
        try self.emitLoadConst(r, vs.const_idx.?);
    } else if (vs.local_slot) |slot| {
        // Load from local
        try self.emitLoadLocal(r, slot);
    } else {
        // Value should have been computed and stored somewhere
        return error.ValueNotAvailable;
    }

    // Track that value is now in this register
    vs.regs |= @as(u16, 1) << r;
    self.regs[r] = .{ .value_id = value_id, .dirty = false };

    return r;
}

/// Advance uses after an instruction.
/// Frees registers holding dead values.
fn advanceUses(self: *RegAllocState, inst: ir.Instruction) void {
    for (inst.getOperands()) |operand| {
        const vs = &self.values[operand.id];
        if (vs.uses) |use| {
            // Pop this use
            vs.uses = use.next;
            use.next = self.free_uses;
            self.free_uses = use;

            // If no more uses, free the register
            if (vs.uses == null) {
                self.freeRegs(vs.regs);
                vs.regs = 0;
            }
        }
    }
}

fn freeRegs(self: *RegAllocState, mask: u16) void {
    var m = mask;
    while (m != 0) {
        const r: u4 = @ctz(m);
        m &= ~(@as(u16, 1) << r);
        self.regs[r] = .{ .value_id = null, .dirty = false };
        self.used &= ~(@as(u16, 1) << r);
    }
}
```

### Phase 4: Integration with BytecodeEmitter

Modify `BytecodeEmitter` to use the new allocator:

```zig
pub const BytecodeEmitter = struct {
    // ... existing fields ...

    // NEW: Proper register allocator
    reg_state: RegAllocState,

    pub fn emitFunction(self: *Self, func: *const ir.Function) !void {
        // Initialize register state for this function
        try self.reg_state.init(func);
        defer self.reg_state.deinit();

        // Compute use distances (backwards pass)
        try self.reg_state.computeUseDistances(func);

        // Process instructions (forward pass)
        for (func.blocks.items) |block| {
            for (block.instructions.items) |inst| {
                try self.emitInstruction(inst);
                self.reg_state.advanceUses(inst);
            }
        }
    }
};
```

### Phase 5: Update Instruction Emitters

Change `emitStrSlice` and similar functions:

```zig
pub fn emitStrSlice(e: *BytecodeEmitter, s: ir.Instruction.StrSlice) !void {
    // Allocate all operands first - allocator handles conflicts
    const src_reg = try e.reg_state.allocValToReg(s.source.id, 0xFFFF);
    const start_reg = try e.reg_state.allocValToReg(s.start.id, 0xFFFF);
    const end_reg = try e.reg_state.allocValToReg(s.length_or_end.id, 0xFFFF);

    // Allocate output register (can reuse input if dead)
    const dest_reg = try e.reg_state.allocReg(0xFFFF);

    // Emit instruction
    try e.emitOpcode(.str_slice);
    try e.emitU8((@as(u8, dest_reg) << 4) | src_reg);
    try e.emitU8((@as(u8, start_reg) << 4) | end_reg);
    try e.emitU8(if (s.is_length) 1 else 0);

    // Track output
    e.reg_state.values[s.result.id].regs |= @as(u16, 1) << dest_reg;
    e.reg_state.regs[dest_reg] = .{ .value_id = s.result.id, .dirty = true };
}
```

## Migration Strategy

### Step 1: Create New Allocator (non-breaking)
- Implement `RegAllocState` and all methods
- Add comprehensive tests
- Don't integrate yet

### Step 2: Add Parallel Tracking
- Keep existing `RegisterAllocator`
- Add `RegAllocState` alongside
- Log differences to validate

### Step 3: Switch Over
- Replace `getValueInReg` calls with `allocValToReg`
- Remove old `RegisterAllocator`
- Remove all ad-hoc register tracking

### Step 4: Cleanup
- Remove `heap_field_ptrs`, `indirect_fields`, etc. tracking maps
- These become unnecessary with proper allocation
- Simplify `emitFieldPtr` and related functions

## Testing Checklist

1. [ ] Unit tests for `RegAllocState` methods
2. [ ] Test case: `/tmp/test_stack_slice.cot` (stack-allocated struct string slice)
3. [ ] Test case: `/tmp/test_exact.cot` (heap-allocated struct string slice)
4. [ ] Test case: for-loop with dynamic bounds
5. [ ] Self-hosted compiler: `cot compile src/parser.cot -o /tmp/parser.cbo`
6. [ ] All existing tests pass

## Success Criteria

1. No register corruption bugs - values stay in their assigned registers until explicitly spilled
2. Predictable spilling - always spill the value with farthest next use
3. Clean code - no ad-hoc tracking maps for special cases
4. Documented invariants - clear ownership and lifecycle for register assignments

## Key Differences from Current Approach

| Current | New (Go-style) |
|---------|----------------|
| Allocate registers during emission | Pre-compute use distances |
| Spill "whatever is in the register" | Spill farthest-next-use |
| Track special cases (heap_field_ptrs, etc.) | Uniform handling via value state |
| `getValueInReg` picks arbitrary temp reg | `allocValToReg` picks optimal register |
| No knowledge of future uses | Full visibility into use pattern |

## References

- Go's register allocator: `~/learning/go/src/cmd/compile/internal/ssa/regalloc.go`
- Linear scan algorithm: [Poletto & Sarkar, 1999](https://dl.acm.org/doi/10.1145/330249.330250)
- Wikipedia: [Register allocation](https://en.wikipedia.org/wiki/Register_allocation)
