const amd = @import("amd.zig");
const cpuid = @import("cpuid.zig");
const logging = @import("../logging.zig");
const std = @import("std");
const uefi = std.os.uefi;

const Backend = union(enum) {
    amd: amd.Backend,
    none,

    pub fn max_standard_func(self: @This()) u32 {
        return switch (self) {
            .amd => |backend| backend.max_standard_func,
            .none => 0
        };
    }

    pub fn vendor_string(self: @This()) []const u8 {
        return switch (self) {
            .amd => amd.VendorString,
            .none => "Unknown"
        };
    }
};

fn detect() Backend {
    const basic_info = cpuid.max_standard_func_and_vendor();

    if (std.mem.eql(u8, basic_info.vendor[0..12], amd.VendorString)) {
        return .{
            .amd = .{
                .max_standard_func = basic_info.max_standard_func
            }
        };
    } else {
        return .none;
    }
}

pub fn is_virtualization_supported() uefi.Error!bool {
    const cpu = detect();

    try logging.log("");
    try logging.log("CPU Detection");
    try logging.log("=============\r\n");

    try logging.logFormatted(
        "Vendor Backend: {s}",
        .{cpu.vendor_string()}
    );

    // TODO(garrett): Eliminate this log when there are more useful
    // log lines to present.
    try logging.logFormatted(
        "Max Standard Function: 0x{x}",
        .{cpu.max_standard_func()}
    );

    try logging.log("");

    return false;
}
