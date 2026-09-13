const alloc = @import("arch/allocation.zig");
const builtin = @import("builtin");
const inst = @import("arch/x86_64/inst.zig");
const logging = @import("logging.zig");
const paging = @import("arch/x86_64/paging.zig");
const std = @import("std");
const uefi = std.os.uefi;

pub const UefiHandoff = struct { memory_map: uefi.tables.MemoryMapSlice, memory_map_buffer: []u8 };

// NOTE(garrett): This allocator is intentionally a minimal, post-UEFI example. We only select
// the single largest range of conventional memory from our map and never free.
const BootstrapAllocator = struct {
    region: []align(alloc.page_size) u8,
    offset: usize,

    const vtable = alloc.PageAllocator.VTable{ .allocatePages = &allocatePages };

    const Error = error{NoValidMemoryRange};

    pub fn allocatePages(ctx: *anyopaque, count: usize) alloc.PageAllocator.Error!u64 {
        const allocator: *@This() = @ptrCast(@alignCast(ctx));

        // TODO(garrett): Update to overflow-safe math in the presence of dynamic page
        // allocation counts.
        const new_offset = (alloc.page_size * count) + allocator.offset;
        if (new_offset > allocator.region.len) {
            return error.AllocationFailed;
        }

        const old_offset = allocator.offset;
        allocator.offset = new_offset;

        return @intFromPtr(allocator.region.ptr) + old_offset;
    }

    pub fn asPageAllocator(self: *@This()) alloc.PageAllocator {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    pub fn init(memory_map: uefi.tables.MemoryMapSlice) Error!@This() {
        var selected: ?*uefi.tables.MemoryDescriptor = null;
        var iterator = memory_map.iterator();

        while (iterator.next()) |descriptor| {
            if (descriptor.type != .conventional_memory) continue;
            if (selected != null and descriptor.number_of_pages <= selected.?.number_of_pages) continue;

            logging.logFormatted("Memory Selection: 0x{x} for {d} pages", .{ descriptor.physical_start, descriptor.number_of_pages });
            selected = descriptor;
        }

        const descriptor = selected orelse return error.NoValidMemoryRange;

        // TODO(garrett): We assume we still have the identity-mapped pages inherited from the UEFI firmware. When we have our own
        // page tables, this assumption no longer holds and we'll have to adjust the addressing.
        return .{
            .region = @as([*]align(alloc.page_size) u8, @ptrFromInt(descriptor.physical_start))[0..(descriptor.number_of_pages * alloc.page_size)],
            .offset = 0,
        };
    }
};

const Architecture = switch (builtin.cpu.arch) {
    .x86_64 => @import("arch/x86_64.zig"),
    else => |architecture| @compileError("Unsupported architecture: " ++ @tagName(architecture)),
};

fn hlt() noreturn {
    while (true) {
        asm volatile (
            \\cli
            \\hlt
        );
    }
}

pub fn enter(handoff_data: UefiHandoff) noreturn {
    var cpu = Architecture.detect() catch {
        logging.log("Unsupported processor vendor detected.");
        hlt();
    };

    var bootstrap_allocator = BootstrapAllocator.init(handoff_data.memory_map) catch {
        logging.log("No valid memory range could be found for initialization.");
        hlt();
    };

    const allocator = bootstrap_allocator.asPageAllocator();
    Architecture.initializeHostAddressSpace(allocator) catch {
        logging.log("Failed to initialize host address space.");
        hlt();
    };

    cpu.prepareVirtualization(allocator) catch |err| switch (err) {
        error.MemoryRequestFailed => {
            logging.log("Required memory could not be allocated.");
            hlt();
        },
        error.VirtualizationDisabled => {
            logging.log("Virtualization has been disabled, please check firmware settings.");
            hlt();
        },
        error.VirtualizationNotSupported => {
            logging.log("Processor does not support virtualization.");
            hlt();
        },
        else => {
            logging.log("An unknown error occurred; aborting.");
            hlt();
        },
    };

    const status = cpu.runGuest();

    switch (status) {
        .halt => logging.log("Guest boot successful!"),
        .invalid_guest_state => logging.log("Guest was configured incorrectly and could not boot."),
    }

    logging.log("Hypervisor gracefully terminating...");
    hlt();
}
