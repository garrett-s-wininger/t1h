const amd = @import("x86_64/amd.zig");
const alloc = @import("allocation.zig");
const cpuid = @import("x86_64/cpuid.zig");
const idt = @import("x86_64/idt.zig");
const inst = @import("x86_64/inst.zig");
const paging = @import("x86_64/paging.zig");
const std = @import("std");

pub const Error = error{
    MemoryRequestFailed,
    UnknownVendor,
    VirtualizationDisabled,
    VirtualizationNotSupported,
};

pub const FaultInfo = idt.FaultInfo;
pub const GuestExit = enum { halt, invalid_guest_state };

pub const Backend = union(enum) {
    // TODO(garrett): Add Intel variant
    amd: amd.Backend,

    pub fn prepareVirtualization(self: *@This(), allocator: alloc.PageAllocator) Error!void {
        return switch (self.*) {
            .amd => |*backend| {
                if (!backend.isVirtualizationSupported()) return error.VirtualizationNotSupported;
                if (backend.isVirtualizationDisabled()) return error.VirtualizationDisabled;

                // TODO(garrett): Move from our hardcoded 2-page host save area and vm control
                // to a more dynamic setup.
                const allocation_start_address = allocator.allocatePages(2) catch {
                    return error.MemoryRequestFailed;
                };

                backend.prepareVirtualization(allocation_start_address);
            },
        };
    }

    pub fn maxExtendedFunc(self: @This()) u32 {
        return switch (self) {
            .amd => |backend| backend.max_extended_func,
        };
    }

    pub fn maxStandardFunc(self: @This()) u32 {
        return switch (self) {
            .amd => |backend| backend.max_standard_func,
        };
    }

    pub fn runGuest(self: @This()) GuestExit {
        return switch (self) {
            .amd => |backend| {
                const exit_code = backend.runGuest();

                switch (exit_code) {
                    0x78 => return .halt,
                    else => return .invalid_guest_state,
                }
            },
        };
    }

    pub fn vendorString(self: @This()) []const u8 {
        return switch (self) {
            .amd => amd.vendor_string,
        };
    }
};

pub fn detect() Error!Backend {
    const basic_info = cpuid.max_standard_func_and_vendor();

    if (std.mem.eql(u8, basic_info.vendor[0..12], amd.vendor_string)) {
        return .{
            .amd = .{
                .max_extended_func = cpuid.max_extended_func(),
                .max_standard_func = basic_info.max_standard_func,
                .vmcb = null,
            },
        };
    } else {
        return error.UnknownVendor;
    }
}

// TODO(garrett): We blindly assume a 1GiB range is appropriate for our use case in this setup.
// Additional work is needed for a more robust virtual memory mapping implementation.
pub fn initializeHostAddressSpace(allocator: alloc.PageAllocator) Error!void {
    // NOTE(garrett): x86_64 defines each level of the memory mapping to be a page each. Since
    // we're using 2MiB large pages, the PTE level is not required so we only have 3 pages
    // encompassing the PML4, PDPT, and PDT levels that are required.
    const page_table_start = allocator.allocatePages(3) catch {
        return error.MemoryRequestFailed;
    };

    const page_directory_pointer_start = page_table_start + alloc.page_size;
    const page_directory_table_start = page_table_start + (2 * alloc.page_size);

    const page_tables: []align(alloc.page_size) u8 = @as(
        [*]align(alloc.page_size) u8,
        @ptrFromInt(page_table_start),
    )[0 .. alloc.page_size * 3];

    @memset(page_tables, 0);

    const pdt: *paging.PageDirectoryTable = @ptrFromInt(page_directory_table_start);
    const two_mib = 2 * 1024 * 1024;

    for (pdt, 0..) |*entry, idx| {
        entry.page_table_address = @truncate((two_mib * idx) >> 12);
        entry._low = paging.present | paging.read_write | paging.large_page;
    }

    const pdpt: *paging.PageDirectoryPointerTable = @ptrFromInt(page_directory_pointer_start);
    pdpt[0].page_directory_address = @truncate(page_directory_table_start >> 12);
    pdpt[0]._low = pdpt[0]._low | paging.present | paging.read_write;

    const pml4: *paging.PageMapLevel4Table = @ptrFromInt(page_table_start);
    pml4[0].page_directory_pointer_address = @truncate(page_directory_pointer_start >> 12);
    pml4[0]._low = pml4[0]._low | paging.present | paging.read_write;

    inst.writeCr3(page_table_start);
}

pub fn initializeInterrupts(handler: idt.FatalFaultHandler) void {
    idt.fatal_fault_handler = handler;

    const code_segment = inst.readCodeSegment();

    for (0..idt.interrupt_table.len) |idx| {
        idt.interrupt_table[idx] = idt.gateForAddress(
            code_segment,
            @intFromPtr(&idt.defaultHandler),
        );
    }

    idt.interrupt_table[idt.invalid_opcode_vector] = idt.gateForAddress(
        code_segment,
        @intFromPtr(&idt.invalidOpcodeEntry),
    );

    idt.interrupt_table[idt.general_protection_vector] = idt.gateForAddress(
        code_segment,
        @intFromPtr(&idt.generalProtectionFaultEntry),
    );

    idt.interrupt_table[idt.page_fault_vector] = idt.gateForAddress(
        code_segment,
        @intFromPtr(&idt.pageFaultEntry),
    );

    var interrupt_descriptor_register = inst.DescriptorTableRegister{
        .limit = @sizeOf(idt.InterruptDescriptorTable) - 1,
        .base = @intFromPtr(&idt.interrupt_table),
    };

    inst.loadInterruptDescriptorTable(&interrupt_descriptor_register);
}

pub fn hlt() noreturn {
    while (true) {
        asm volatile (
            \\cli
            \\hlt
        );
    }
}

pub fn nameForInterruptVector(interrupt_vector: u8) []const u8 {
    switch (interrupt_vector) {
        idt.invalid_opcode_vector => return "Invalid Opcode",
        idt.general_protection_vector => return "General Protection Fault",
        idt.page_fault_vector => return "Page Fault",
        else => return "Unknown Fault",
    }
}
