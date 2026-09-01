const std = @import("std");
const uefi = std.os.uefi;
const unicode = std.unicode;

pub fn main() uefi.Error!void {
    const console_out = uefi.system_table.con_out orelse return error.DeviceError;
    const message = unicode.utf8ToUtf16LeStringLiteral("Entered T1H UEFI initialization...\r\n");

    _ = try console_out.outputString(message);

    // TODO(garrett): Use a key press or other means of pausing, rather than CPU halt while we're
    // developing.
    while (true) asm volatile ("hlt");

    return;
}
