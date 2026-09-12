const alloc = @import("arch/allocation.zig");
const builtin = @import("builtin");
const std = @import("std");
const logging = @import("logging.zig");
const uart = @import("peripherals/uart.zig");
const uefi = std.os.uefi;

const Architecture = switch (builtin.cpu.arch) {
    .x86_64 => @import("arch/x86_64.zig"),
    else => |architecture| @compileError("Unsupported architecture: " ++ @tagName(architecture)),
};

const UefiPageAllocator = struct {
    fn allocatePages(ctx: *anyopaque, count: usize) alloc.PageAllocator.Error!u64 {
        const boot_services: *uefi.tables.BootServices = @ptrCast(@alignCast(ctx));
        const pages = boot_services.allocatePages(.any, .loader_data, count) catch {
            return error.AllocationFailed;
        };

        return @intFromPtr(pages.ptr);
    }

    const vtable = alloc.PageAllocator.VTable{
        .allocatePages = allocatePages,
    };

    pub fn new() uefi.Error!alloc.PageAllocator {
        if (uefi.system_table.boot_services) |boot_services| {
            return .{ .ptr = boot_services, .vtable = &vtable };
        }

        return error.Unsupported;
    }
};

fn logBootFailure(comptime message: []const u8) void {
    logging.log("");
    logging.log("Error");
    logging.log("=====\r\n");
    logging.log(message ++ " Hypervisor failed to intialize.");
}

fn logGuestBootSuccessful() void {
    logging.log("");
    logging.log("Guest Boot Status");
    logging.log("=================\r\n");
    logging.log("VM launch successful!");
}

fn logCpuDetection(backend: Architecture.Backend) void {
    logging.log("");
    logging.log("CPU Detection");
    logging.log("=============\r\n");
    logging.logFormatted("Vendor: {s}", .{backend.vendorString()});
}

fn logHeader() void {
    logging.log("T1H v0.0.0");
    logging.log("==========\r\n");
    logging.log("Entered T1H UEFI initialization...");
}

fn postBootServices() void {
    @panic(std.fmt.comptimePrint("\r\nReached Unimplemented Code: {s}:{d}:{d} ({s})\r\n", .{ @src().file, @src().line, @src().column, @src().fn_name }));
}

pub fn main() uefi.Error!void {
    // TODO(garrett): Don't hardcode COM1, automatically detect and select
    // a console UART.
    uart.init(uart.com1);
    logHeader();

    var cpu = Architecture.detect() catch {
        logBootFailure("Unsupported processor vendor detected.");
        return error.Unsupported;
    };

    // TODO(garrett): Move this over into a different page allocator
    // once we exit boot services.
    const allocator = UefiPageAllocator.new() catch {
        logBootFailure("Unable to initialize page allocation.");
        return error.Unsupported;
    };

    logCpuDetection(cpu);
    cpu.prepareVirtualization(allocator) catch |err| switch (err) {
        error.MemoryRequestFailed => {
            logBootFailure("Required memory could not be allocated.");
            return error.OutOfResources;
        },
        error.VirtualizationDisabled => {
            logBootFailure("Virtualization has been disabled, please check firmware settings.");
            return error.DeviceError;
        },
        error.VirtualizationNotSupported => {
            logBootFailure("Processor does not support virtualization.");
            return error.Unsupported;
        },
        else => {
            logBootFailure("An unknown error occurred; aborting.");
            return error.Aborted;
        },
    };

    const status = cpu.runGuest();

    switch (status) {
        .halt => logGuestBootSuccessful(),
        .invalid_guest_state => logBootFailure("Guest was configured incorrectly and could not boot."),
    }

    postBootServices();
}
