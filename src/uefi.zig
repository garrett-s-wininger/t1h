const alloc = @import("arch/allocation.zig");
const builtin = @import("builtin");
const std = @import("std");
const logging = @import("logging.zig");
const uefi = std.os.uefi;

const Architecture = switch (builtin.cpu.arch) {
    .x86_64 => @import("arch/x86_64.zig"),
    else => |architecture| @compileError("Unsupported architecture: " ++ @tagName(architecture)),
};

const UefiPageAllocator = struct {
    fn allocatePages(ctx: *anyopaque, count: usize) alloc.PageAllocator.Error!u64 {
        const boot_services: *uefi.tables.BootServices = @ptrCast(@alignCast(ctx));
        const pages = boot_services.allocatePages(
            .any,
            .loader_data,
            count
        ) catch {
            return error.AllocationFailed;
        };

        return @intFromPtr(pages.ptr);
    }

    const vtable = alloc.PageAllocator.VTable{
        .allocatePages = allocatePages,
    };

    pub fn new() uefi.Error!alloc.PageAllocator {
        if (uefi.system_table.boot_services) |boot_services| {
            return .{
                .ptr = boot_services,
                .vtable = &vtable
            };
        }

        return error.Unsupported;
    }
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

    // TODO(garrett): Move this over into a different page allocator
    // once we exit boot services.
    const allocator = UefiPageAllocator.new() catch {
        try logBootFailure("Unable to initialize page allocation.");
        return error.Unsupported;
    };

    try logCpuDetection(cpu);
    cpu.prepareVirtualization(allocator) catch |err| switch (err) {
        error.MemoryRequestFailed => try logBootFailure("Required memory could not be allocated."),
        error.VirtualizationDisabled => try logBootFailure("Virtualization has been disabled, please check firmware settings."),
        error.VirtualizationNotSupported => try logBootFailure("Processor does not support virtualization."),
        else => {}
    };

    // TODO(garrett): Use a key press or other means of pausing, rather than CPU halt.
    while (true) asm volatile ("hlt");
}
