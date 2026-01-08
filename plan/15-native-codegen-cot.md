# Cot Native Code Generator - Execution Plan

**Goal:** Write a native code emitter in Cot that compiles Cot bytecode to ARM64/x86_64 machine code, achieving true self-hosting.

## Current State

| Component | Status | Notes |
|-----------|--------|-------|
| gen_dev (Rust) | ~42 opcodes | Core ops, control flow, locals, records |
| Cranelift (Rust) | 177 opcodes | Full coverage, optimized |
| Cot emit.cot | Bytecode only | Needs native backend |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Cot Compiler                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐ │
│  │  lexer   │→ │  parser  │→ │  lower   │→ │  emit   │ │
│  └──────────┘  └──────────┘  └──────────┘  └────┬────┘ │
│                                                  │      │
│                              ┌───────────────────┼──────┤
│                              │                   │      │
│                              ▼                   ▼      │
│                        ┌──────────┐       ┌──────────┐  │
│                        │ Bytecode │       │  Native  │  │
│                        │  (.cbo)  │       │  (.o)    │  │
│                        └──────────┘       └──────────┘  │
│                                                  │      │
│                        NEW: emit_native.cot ─────┘      │
└─────────────────────────────────────────────────────────┘
```

## Phase 1: ARM64 Assembler Module (`asm_arm64.cot`)

**Estimated: 400-500 lines**

### 1.1 Core Data Structures

```cot
// ARM64 register
enum Reg {
    X0, X1, X2, X3, X4, X5, X6, X7,
    X8, X9, X10, X11, X12, X13, X14, X15,
    X16, X17, X18, X19, X20, X21, X22, X23,
    X24, X25, X26, X27, X28, X29, X30, XZR
}

// Cot register to ARM64 mapping
fn cotToArm(r: int) -> Reg {
    switch (r) {
        0 => Reg.X0,
        1 => Reg.X1,
        // ... r0-r7 → x0-x7
        8 => Reg.X19,  // Callee-saved
        // ... r8-r13 → x19-x24
        14 => Reg.X29, // FP
        15 => Reg.X0,  // Return value
    }
}

struct Assembler {
    code: List<int>,      // Machine code bytes (as u32 words)
    relocations: List<Relocation>,
}
```

### 1.2 Instruction Encoding Functions

```cot
impl Assembler {
    // Emit 32-bit instruction
    fn emit(self, inst: int) {
        self.code.push(inst)
    }

    // ADD Xd, Xn, Xm
    fn add(self, rd: Reg, rn: Reg, rm: Reg) {
        // 0x8B000000 | (rm << 16) | (rn << 5) | rd
        let inst = 0x8B000000 | (rm.value() << 16) | (rn.value() << 5) | rd.value()
        self.emit(inst)
    }

    // SUB Xd, Xn, Xm
    fn sub(self, rd: Reg, rn: Reg, rm: Reg) {
        let inst = 0xCB000000 | (rm << 16) | (rn << 5) | rd
        self.emit(inst)
    }

    // MUL Xd, Xn, Xm (actually MADD Xd, Xn, Xm, XZR)
    fn mul(self, rd: Reg, rn: Reg, rm: Reg) {
        let inst = 0x9B007C00 | (rm << 16) | (rn << 5) | rd
        self.emit(inst)
    }

    // SDIV Xd, Xn, Xm
    fn sdiv(self, rd: Reg, rn: Reg, rm: Reg) {
        let inst = 0x9AC00C00 | (rm << 16) | (rn << 5) | rd
        self.emit(inst)
    }

    // MOV Xd, Xn (alias for ORR Xd, XZR, Xn)
    fn mov(self, rd: Reg, rn: Reg) {
        let inst = 0xAA0003E0 | (rn << 16) | rd
        self.emit(inst)
    }

    // MOVZ Xd, #imm16, LSL #shift
    fn movz(self, rd: Reg, imm: int, shift: int) {
        let hw = shift / 16
        let inst = 0xD2800000 | (hw << 21) | ((imm & 0xFFFF) << 5) | rd
        self.emit(inst)
    }

    // MOVK Xd, #imm16, LSL #shift
    fn movk(self, rd: Reg, imm: int, shift: int) {
        let hw = shift / 16
        let inst = 0xF2800000 | (hw << 21) | ((imm & 0xFFFF) << 5) | rd
        self.emit(inst)
    }

    // B offset (unconditional branch)
    fn b(self, offset: int) {
        let imm26 = (offset >> 2) & 0x3FFFFFF
        let inst = 0x14000000 | imm26
        self.emit(inst)
    }

    // BL offset (branch and link - call)
    fn bl(self, offset: int) {
        let imm26 = (offset >> 2) & 0x3FFFFFF
        let inst = 0x94000000 | imm26
        self.emit(inst)
    }

    // CBZ Xn, offset (compare and branch if zero)
    fn cbz(self, rn: Reg, offset: int) {
        let imm19 = (offset >> 2) & 0x7FFFF
        let inst = 0xB4000000 | (imm19 << 5) | rn
        self.emit(inst)
    }

    // CBNZ Xn, offset
    fn cbnz(self, rn: Reg, offset: int) {
        let imm19 = (offset >> 2) & 0x7FFFF
        let inst = 0xB5000000 | (imm19 << 5) | rn
        self.emit(inst)
    }

    // RET (return via X30)
    fn ret(self) {
        self.emit(0xD65F03C0)
    }

    // LDR Xd, [Xn, #offset]
    fn ldr(self, rd: Reg, rn: Reg, offset: int) {
        let imm12 = (offset >> 3) & 0xFFF
        let inst = 0xF9400000 | (imm12 << 10) | (rn << 5) | rd
        self.emit(inst)
    }

    // STR Xd, [Xn, #offset]
    fn str(self, rd: Reg, rn: Reg, offset: int) {
        let imm12 = (offset >> 3) & 0xFFF
        let inst = 0xF9000000 | (imm12 << 10) | (rn << 5) | rd
        self.emit(inst)
    }

    // STP X1, X2, [SP, #-16]! (push pair)
    fn stp_pre(self, rt1: Reg, rt2: Reg, rn: Reg, offset: int) {
        let imm7 = (offset >> 3) & 0x7F
        let inst = 0xA9BF0000 | (imm7 << 15) | (rt2 << 10) | (rn << 5) | rt1
        self.emit(inst)
    }

    // LDP X1, X2, [SP], #16 (pop pair)
    fn ldp_post(self, rt1: Reg, rt2: Reg, rn: Reg, offset: int) {
        let imm7 = (offset >> 3) & 0x7F
        let inst = 0xA8C10000 | (imm7 << 15) | (rt2 << 10) | (rn << 5) | rt1
        self.emit(inst)
    }

    // CMP Xn, Xm (alias for SUBS XZR, Xn, Xm)
    fn cmp(self, rn: Reg, rm: Reg) {
        let inst = 0xEB00001F | (rm << 16) | (rn << 5)
        self.emit(inst)
    }

    // CSET Xd, cond (conditional set)
    fn cset(self, rd: Reg, cond: int) {
        // CSINC Xd, XZR, XZR, invert(cond)
        let inv_cond = cond ^ 1
        let inst = 0x9A9F07E0 | (inv_cond << 12) | rd
        self.emit(inst)
    }

    // NOP
    fn nop(self) {
        self.emit(0xD503201F)
    }
}
```

## Phase 2: Native Emitter (`emit_native.cot`)

**Estimated: 800-1000 lines**

### 2.1 Compiler State

```cot
struct NativeCompiler {
    module: *Module,           // Bytecode module
    asm: Assembler,            // ARM64 assembler

    // Local variable stack slots (offset from FP)
    local_offsets: List<int>,
    stack_size: int,

    // Relocation tracking
    jump_relocs: List<JumpReloc>,
    call_relocs: List<CallReloc>,

    // Bytecode IP → native offset mapping
    bc_to_native: Map<int, int>,

    // Routine info
    routine_offsets: List<int>,  // Start offset of each routine
}

struct JumpReloc {
    native_offset: int,   // Where the jump instruction is
    target_bc_ip: int,    // Target bytecode IP
}

struct CallReloc {
    native_offset: int,
    routine_idx: int,
}
```

### 2.2 Core Compilation Loop

```cot
impl NativeCompiler {
    fn compileRoutine(self, routine_idx: int) {
        let routine = self.module.routines[routine_idx]
        let bc_start = routine.code_offset
        let bc_end = bc_start + routine.code_length

        // Function prologue
        self.emitPrologue(routine.local_count)

        // Record routine start
        self.routine_offsets[routine_idx] = self.asm.offset()

        // Compile each opcode
        let ip = bc_start
        while (ip < bc_end) {
            self.bc_to_native[ip] = self.asm.offset()

            let opcode = self.module.code[ip]
            let op = Opcode.fromByte(opcode)
            let operands = self.readOperands(ip, op)

            self.compileOpcode(op, operands, ip)
            ip = ip + 1 + op.operandSize()
        }

        // Function epilogue (if not already returned)
        self.emitEpilogue()
    }

    fn emitPrologue(self, local_count: int) {
        // Save FP and LR
        self.asm.stp_pre(Reg.X29, Reg.X30, Reg.SP, -16)
        // Set up frame pointer
        self.asm.mov(Reg.X29, Reg.SP)

        // Allocate stack space for locals
        self.stack_size = (local_count + 1) * 8
        if (self.stack_size > 0) {
            self.asm.sub_imm(Reg.SP, Reg.SP, self.stack_size)
        }

        // Save callee-saved registers if needed
        self.asm.stp_pre(Reg.X19, Reg.X20, Reg.SP, -16)
        self.asm.stp_pre(Reg.X21, Reg.X22, Reg.SP, -16)
        self.asm.stp_pre(Reg.X23, Reg.X24, Reg.SP, -16)
    }

    fn emitEpilogue(self) {
        // Restore callee-saved registers
        self.asm.ldp_post(Reg.X23, Reg.X24, Reg.SP, 16)
        self.asm.ldp_post(Reg.X21, Reg.X22, Reg.SP, 16)
        self.asm.ldp_post(Reg.X19, Reg.X20, Reg.SP, 16)

        // Deallocate stack
        if (self.stack_size > 0) {
            self.asm.add_imm(Reg.SP, Reg.SP, self.stack_size)
        }

        // Restore FP and LR, return
        self.asm.ldp_post(Reg.X29, Reg.X30, Reg.SP, 16)
        self.asm.ret()
    }
}
```

### 2.3 Opcode Compilation (Grouped by Category)

```cot
fn compileOpcode(self, op: Opcode, operands: []int, bc_ip: int) {
    switch (op) {
        // === Arithmetic ===
        Opcode.Add | Opcode.AddInt => {
            let rd = (operands[0] >> 4) & 0xF
            let rs1 = operands[0] & 0xF
            let rs2 = (operands[1] >> 4) & 0xF
            self.asm.add(cotToArm(rd), cotToArm(rs1), cotToArm(rs2))
        }

        Opcode.Sub | Opcode.SubInt => {
            let rd = (operands[0] >> 4) & 0xF
            let rs1 = operands[0] & 0xF
            let rs2 = (operands[1] >> 4) & 0xF
            self.asm.sub(cotToArm(rd), cotToArm(rs1), cotToArm(rs2))
        }

        // ... Mul, Div, Mod, Neg, Incr, Decr

        // === Control Flow ===
        Opcode.Jmp => {
            let offset = readI16(operands, 1)
            let target = bc_ip + 4 + offset
            self.emitJump(target, false)
        }

        Opcode.Jz => {
            let reg = operands[0] & 0xF
            let offset = readI16(operands, 1)
            let target = bc_ip + 4 + offset
            self.emitCondJump(cotToArm(reg), target, true)
        }

        Opcode.Jnz => {
            let reg = operands[0] & 0xF
            let offset = readI16(operands, 1)
            let target = bc_ip + 4 + offset
            self.emitCondJump(cotToArm(reg), target, false)
        }

        Opcode.Call => {
            let routine_idx = readU16(operands, 0)
            self.emitCall(routine_idx)
        }

        Opcode.Ret => {
            self.emitEpilogue()
        }

        Opcode.RetVal => {
            let reg = (operands[0] >> 4) & 0xF
            // Move return value to X0
            if (reg != 0) {
                self.asm.mov(Reg.X0, cotToArm(reg))
            }
            self.emitEpilogue()
        }

        // === Local Variables ===
        Opcode.LoadLocal => {
            let dst = (operands[0] >> 4) & 0xF
            let slot = operands[1]
            let offset = self.localOffset(slot)
            self.asm.ldr(cotToArm(dst), Reg.X29, offset)
        }

        Opcode.StoreLocal => {
            let src = (operands[0] >> 4) & 0xF
            let slot = operands[1]
            let offset = self.localOffset(slot)
            self.asm.str(cotToArm(src), Reg.X29, offset)
        }

        // === Comparisons ===
        Opcode.CmpEq | Opcode.CmpEqInt => {
            let rd = (operands[0] >> 4) & 0xF
            let rs1 = operands[0] & 0xF
            let rs2 = (operands[1] >> 4) & 0xF
            self.asm.cmp(cotToArm(rs1), cotToArm(rs2))
            self.asm.cset(cotToArm(rd), COND_EQ)  // 0 = EQ
        }

        // ... CmpNe, CmpLt, CmpLe, CmpGt, CmpGe

        // === Memory ===
        Opcode.NewRecord => {
            // Allocate record via malloc
            let dst = (operands[0] >> 4) & 0xF
            let size = operands[1]
            self.emitMalloc(cotToArm(dst), size * 8)
        }

        Opcode.LoadField => {
            let dst = (operands[0] >> 4) & 0xF
            let obj = operands[0] & 0xF
            let field = operands[1]
            self.asm.ldr(cotToArm(dst), cotToArm(obj), field * 8)
        }

        Opcode.StoreField => {
            let src = (operands[0] >> 4) & 0xF
            let obj = operands[0] & 0xF
            let field = operands[1]
            self.asm.str(cotToArm(src), cotToArm(obj), field * 8)
        }

        // ... Lists, Maps, Strings (using runtime calls)

        _ => {
            // Unimplemented - emit nop
            self.asm.nop()
        }
    }
}
```

## Phase 3: Object File Emission (`object_macho.cot`)

**Estimated: 300-400 lines**

### 3.1 Mach-O Structure

```cot
struct MachOBuilder {
    code: List<int>,           // Code section
    data: List<int>,           // Data section (strings, constants)
    symbols: List<Symbol>,     // Symbol table
    relocations: List<Reloc>,  // Relocations
}

struct Symbol {
    name: string,
    offset: int,
    size: int,
    is_external: bool,
}

impl MachOBuilder {
    fn addRoutine(self, name: string, code: []int) {
        let offset = self.code.len()
        for inst in code {
            self.code.push(inst)
        }
        self.symbols.push(Symbol {
            name: name,
            offset: offset,
            size: code.len() * 4,
            is_external: true,
        })
    }

    fn addString(self, s: string) -> int {
        let offset = self.data.len()
        for c in s {
            self.data.push(c as int)
        }
        self.data.push(0)  // null terminator
        return offset
    }

    fn emit(self) -> []int {
        // Build Mach-O header
        let header = self.buildHeader()
        // Build load commands
        let commands = self.buildLoadCommands()
        // Build sections
        let sections = self.buildSections()
        // Build symbol table
        let symtab = self.buildSymbolTable()
        // Combine all parts
        return concat(header, commands, sections, symtab)
    }
}
```

## Phase 4: Integration & Testing

### 4.1 New Compiler Entry Point

```cot
// In driver.cot or new native_driver.cot
fn compileToNative(source_files: []string, output: string) {
    // Parse and compile to bytecode (existing pipeline)
    let module = compileToModule(source_files)

    // Native compilation
    let native = NativeCompiler.new(module)
    native.compile()

    // Emit object file
    let obj = MachOBuilder.new()
    for i in 0..module.routines.len() {
        let name = module.getRoutineName(i)
        let code = native.getRoutineCode(i)
        obj.addRoutine(name, code)
    }

    // Add string constants
    for i in 0..module.constants.len() {
        if (module.constants[i] is String) {
            obj.addString(module.constants[i])
        }
    }

    // Write object file
    writeFile(output, obj.emit())
}
```

### 4.2 Test Strategy

1. **Unit tests for assembler**
   - Test each instruction encoding
   - Compare against known-good encodings from gen_dev

2. **Simple function tests**
   - Return constant
   - Arithmetic expressions
   - Local variables

3. **Control flow tests**
   - Conditionals
   - Loops
   - Function calls

4. **Bootstrap test**
   - Compile cot-compiler with Cot-native
   - Compare output with Cranelift-compiled version

## Implementation Order

| Phase | Component | Est. Lines | Depends On |
|-------|-----------|------------|------------|
| 1.1 | Reg enum + mapping | 50 | - |
| 1.2 | Basic instructions (add, sub, mov) | 100 | 1.1 |
| 1.3 | Memory instructions (ldr, str) | 80 | 1.1 |
| 1.4 | Control flow (b, bl, cbz) | 100 | 1.1 |
| 1.5 | Full instruction set | 150 | 1.2-1.4 |
| 2.1 | Compiler state + prologue/epilogue | 150 | 1.* |
| 2.2 | Arithmetic opcodes | 100 | 2.1 |
| 2.3 | Control flow opcodes | 150 | 2.1 |
| 2.4 | Memory opcodes | 200 | 2.1 |
| 2.5 | Relocation patching | 100 | 2.* |
| 3.1 | Mach-O header/commands | 150 | - |
| 3.2 | Symbol table | 100 | 3.1 |
| 3.3 | Full object emission | 150 | 3.* |
| 4.1 | Integration | 100 | 2.*, 3.* |
| 4.2 | Tests | 200 | 4.1 |

**Total: ~1,800-2,000 lines of Cot**

## Alternative: Start with Simpler ELF

Instead of Mach-O, we could emit raw code + use `ld` for object file creation:

```bash
# Emit raw machine code
./cot-native emit-raw program.cot -o program.bin

# Use system assembler to create object file
as -o program.o program.s  # If we emit assembly text

# Or use ld directly with binary input
ld -r -b binary -o program.o program.bin
```

This defers Mach-O/ELF complexity to later.

## Success Criteria

1. ✅ `asm_arm64.cot` can encode all ARM64 instructions used
2. ✅ `emit_native.cot` compiles simple programs correctly
3. ✅ `object_macho.cot` produces valid object files
4. ✅ Can compile and run "Hello World" natively
5. ✅ Can compile cot-compiler to native (bootstrap)
6. ✅ Self-compiled cot-native produces identical output

## References

- gen_dev source: `cot-rs/src/native_gen/aarch64.rs`
- ARM64 instruction reference: ARM Architecture Reference Manual
- Mach-O format: Apple Developer Documentation
