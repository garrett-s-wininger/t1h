const std = @import("std");
const uefi = std.os.uefi;
const unicode = std.unicode;

const max_line_utf8 = 80;
const max_line_utf16 = max_line_utf8 * 2;

pub fn log(comptime message: []const u8) uefi.Error!void {
    try writeUtf16(unicode.utf8ToUtf16LeStringLiteral(message ++ "\r\n"));
}

pub fn logFormatted(comptime format: []const u8, args: anytype) uefi.Error!void {
    var buffer: [max_line_utf8]u8 = undefined;
    const message = std.fmt.bufPrint(&buffer, format, args) catch |err| switch (err) {
        error.NoSpaceLeft => return error.BufferTooSmall,
    };

    try writeUtf8(message);
}

fn writeUtf8(message: []const u8) uefi.Error!void {
    var buffer: [max_line_utf16]u16 = undefined;
    const length = unicode.utf8ToUtf16Le(buffer[0..], message) catch |err| switch (err) {
        error.InvalidUtf8 => return error.Unexpected,
    };

    if (length + 2 >= max_line_utf16 + 2) return error.BufferTooSmall;

    buffer[length] = '\r';
    buffer[length + 1] = '\n';
    buffer[length + 2] = 0;

    try writeUtf16(buffer[0 .. length + 2 :0]);
}

fn writeUtf16(message: [*:0]const u16) uefi.Error!void {
    if (uefi.system_table.con_out) |console| {
        _ = try console.outputString(message);
    }
}
