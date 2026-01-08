# Cot Self-Hosted Compiler - Execution Plan

**Goal:** Write the Cot compiler in Cot, achieving self-hosting.

**Current State:** Zig compiler is ~96K lines across 186 files.
**Target:** Cot compiler will be ~8-12K lines (compiler only, no runtime).

## Current Status (2026-01-08)

| Phase | Status |
|-------|--------|
| Phase 0: Prerequisites | ✅ COMPLETE |
| Phase 1: Lexer | ✅ COMPLETE (652 lines) |
| Phase 2: Parser | ✅ COMPLETE (2,242 lines) |
| Phase 3: Type System | ✅ COMPLETE (2,775 lines) |
| Phase 4: IR/Lowering | ✅ COMPLETE (2,292 lines) |
| Phase 5: Bytecode Emit | ✅ COMPLETE (2,137 lines) |
| Phase 6: Bootstrap | 🟢 DRIVER WORKING |

**Driver compiles and runs!** The self-hosted compiler driver can process command-line arguments and is ready for self-compilation testing.

## Plan Documents

1. [Gap Analysis](./01-gap-analysis.md) - What Cot needs vs what exists
2. [Language Prerequisites](./02-language-prerequisites.md) - Features to add/fix before starting
3. [Architecture](./03-architecture.md) - Compiler structure in Cot
4. [Phases](./04-phases.md) - Implementation phases with milestones
5. [Task List](./05-task-list.md) - Granular task breakdown
6. [Feature Parity](./12-feature-parity.md) - Language features needing implementation
7. [Generic Type Support](./12-generic-type-support.md) - ✅ RESOLVED - List<string> support
8. [Compiler Bugs](./13-compiler-bugs.md) - Bug tracking and fixes

## Key Insight

The Zig compiler uses many advanced features that Cot doesn't need:
- Packed structs with bit fields → Use regular structs
- Custom hash contexts → Use string keys
- Arena allocators → Use ARC (automatic)
- Comptime evaluation → Defer to runtime or skip
- defer/errdefer → Use try/catch + manual cleanup

**Strategy:** Build a simpler compiler that produces identical bytecode, not a 1:1 port.

## Success Criteria

```
1. cot compile compiler.cot -o cot-stage1.cbo
2. cot run cot-stage1.cbo -- compile compiler.cot -o cot-stage2.cbo
3. cot-stage1.cbo == cot-stage2.cbo (byte-for-byte identical)
4. Self-hosted compiler passes all existing tests
```

## Timeline Estimate

| Phase | Duration | Cumulative |
|-------|----------|------------|
| 0: Prerequisites | 3-5 days | Week 1 |
| 1: Lexer | 2-3 days | Week 1-2 |
| 2: Parser | 5-7 days | Week 2-3 |
| 3: Type Checker | 4-5 days | Week 3-4 |
| 4: IR/Codegen | 4-5 days | Week 4-5 |
| 5: Bootstrap | 2-3 days | Week 5 |
| **Total** | **20-28 days** | **~5 weeks** |

## Quick Start

After prerequisites are complete:
```bash
cd ~/cotlang/cot-compiler/src
cot compile lexer.cot -o lexer.cbo
cot run lexer.cbo -- test.cot  # Should tokenize test.cot
```
