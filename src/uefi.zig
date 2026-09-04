const builtin = @import("builtin");
const std = @import("std");
const logging = @import("logging.zig");
const uefi = std.os.uefi;

const Architecture = switch (builtin.cpu.arch) {
    .x86_64 => @import("arch/x86_64.zig"),
    else => |architecture| @compileError("Unsupported architecture: " ++ @tagName(architecture)),
};

fn logBootFailure(comptime message: []const u8) uefi.Error!void {
    try logging.log("Error");
    try logging.log("=====\r\n");
    try logging.log(message ++ " Hypervisor failed to intialize.");
}

fn logCpuDetection(backend: Architecture.Backend) uefi.Error!void {
    try logging.log("");
    try logging.log("CPU Detection");
    try logging.log("=============\r\n");
    try logging.logFormatted("Vendor: {s}", .{ backend.vendorString() });
    try logging.log("");
}

fn logHeader() uefi.Error!void {
    try logging.log("T1H v0.0.0");
    try logging.log("==========\r\n");
    try logging.log("Entered T1H UEFI initialization...");
}

pub fn main() uefi.Error!void {
    if (uefi.system_table.con_out) |console| {
        try console.clearScreen();
    }

    try logHeader();

    const cpu = Architecture.detect() catch {
        try logBootFailure("Unsupported processor vendor detected.");
        return error.Unsupported;
    };

    try logCpuDetection(cpu);
    cpu.prepareVirtualization() catch |err| switch (err) {
        error.VirtualizationNotSupported => try logBootFailure("Processor does not support virtualization"),
        else => {}
    };

    // TODO(garrett): Use a key press or other means of pausing, rather than CPU halt.
    while (true) asm volatile ("hlt");
}
