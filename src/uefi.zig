const builtin = @import("builtin");
const std = @import("std");
const logging = @import("logging.zig");
const uefi = std.os.uefi;

fn is_virtualization_supported() uefi.Error!bool {
    const virtualization = switch (builtin.cpu.arch) {
        .x86_64 => @import("virtualization/x86_64.zig"),
        else => |architecture| @compileError("Unsupported architecture: " ++ @tagName(architecture)),
    };

    return try virtualization.is_virtualization_supported();
}

pub fn main() uefi.Error!void {
    try logging.log("");
    try logging.log("T1H v0.0.0");
    try logging.log("==========\r\n");
    try logging.log("Entered T1H UEFI initialization...");

    const virtualizable = try is_virtualization_supported();

    if (!virtualizable) {
        try logging.log("No virtualization support detected. Hypervisor failed to intialize.");
    }

    // TODO(garrett): Use a key press or other means of pausing, rather than CPU halt while we're
    // developing.
    while (true) asm volatile ("hlt");
}
