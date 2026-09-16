const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const riscv64_target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
    });

    const riscv64 = b.addExecutable(.{
        .name = "bootriscv64",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/freestanding.zig"),
            .target = riscv64_target,
            .optimize = optimize,
            .imports = &.{},
            .unwind_tables = .none,
        }),
    });

    riscv64.entry = .{ .symbol_name = "efiMain" };
    riscv64.link_emit_relocs = true;
    riscv64.pie = true;
    riscv64.setLinkerScript(b.path("src/arch/riscv64/uefi.lds"));

    const x86_64_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .uefi,
    });

    const x86_64 = b.addExecutable(.{
        .name = "bootx64",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/uefi.zig"),
            .target = x86_64_target,
            .optimize = optimize,
            .imports = &.{},
        }),
    });

    b.installArtifact(riscv64);
    b.installArtifact(x86_64);
}
