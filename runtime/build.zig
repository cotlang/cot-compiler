const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Static library for linking with native Cot programs
    const lib = b.addLibrary(.{
        .name = "cot_runtime",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("cot_runtime.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(lib);

    // Shared library option
    const shared_lib = b.addLibrary(.{
        .name = "cot_runtime_shared",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("cot_runtime.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const install_shared = b.addInstallArtifact(shared_lib, .{});
    const shared_step = b.step("shared", "Build shared library");
    shared_step.dependOn(&install_shared.step);

    // Tests
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("cot_runtime.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run runtime tests");
    test_step.dependOn(&run_tests.step);
}
