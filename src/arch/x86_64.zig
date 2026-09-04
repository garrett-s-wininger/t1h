const amd = @import("x86_64/amd.zig");
const cpuid = @import("x86_64/cpuid.zig");
const std = @import("std");

pub const Error = error {
    UnknownVendor,
};

pub const Backend = union(enum) {
    // TODO(garrett): Add Intel variant
    amd: amd.Backend,

    pub fn max_standard_func(self: @This()) u32 {
        return switch (self) {
            .amd => |backend| backend.max_standard_func,
        };
    }

    pub fn vendor_string(self: @This()) []const u8 {
        return switch (self) {
            .amd => amd.VendorString,
        };
    }
};

pub fn detect() Error!Backend {
    const basic_info = cpuid.max_standard_func_and_vendor();

    if (std.mem.eql(u8, basic_info.vendor[0..12], amd.VendorString)) {
        return .{
            .amd = .{
                .max_standard_func = basic_info.max_standard_func
            }
        };
    } else {
        return error.UnknownVendor;
    }
}
