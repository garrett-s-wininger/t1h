const std = @import("std");
const uart = @import("peripherals/uart.zig");

const max_line = 80;

pub fn log(comptime message: []const u8) void {
    for (message) |char| {
        uart.putc(uart.com1, char);
    }

    uart.putc(uart.com1, '\r');
    uart.putc(uart.com1, '\n');
}

pub fn logFormatted(comptime format: []const u8, args: anytype) void {
    var buffer: [max_line]u8 = undefined;
    const message = std.fmt.bufPrint(&buffer, format, args) catch {
        return;
    };

    for (message) |char| {
        uart.putc(uart.com1, char);
    }

    uart.putc(uart.com1, '\r');
    uart.putc(uart.com1, '\n');
}
