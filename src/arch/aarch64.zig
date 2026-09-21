const alloc = @import("allocation.zig");
const uart = @import("../peripherals/uart.zig");

// TODO(garrett): Determine by parsing the device tree blob rather than blindly assuming
// we're at the QEMU UART MMIO address.
const uart_base = 0x0900_0000;

pub const ConsoleUart = uart.Pl011(uart.MemoryMapped(u32));
pub const console_uart_base = uart_base;

pub const Error = error{
    MemoryRequestFailed,
    NotImplemented,
    VirtualizationDisabled,
    VirtualizationNotSupported,
};

pub const GuestExit = enum {
    halt,
    invalid_guest_state,
};

pub const Backend = struct {
    pub fn prepareVirtualization(_: *@This(), _: alloc.PageAllocator) Error!void {
        return error.NotImplemented;
    }

    pub fn runGuest(_: @This()) GuestExit {
        return .invalid_guest_state;
    }
};

pub const FaultInfo = struct {};
pub const FatalFaultHandler = *const fn (FaultInfo) noreturn;

pub fn detect() Error!Backend {
    return error.NotImplemented;
}

pub fn initializeHostAddressSpace(_: alloc.PageAllocator) Error!void {}

pub fn initializeHostExecutionContext() Error!void {
    return error.NotImplemented;
}

pub fn initializeInterrupts(_: FatalFaultHandler) void {}

pub fn nameForInterruptVector(_: u8) []const u8 {
    return "Unknown";
}

pub fn hlt() noreturn {
    while (true) {
        asm volatile ("wfi");
    }
}
