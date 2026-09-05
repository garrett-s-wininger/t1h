const amd = @import("x86_64/amd.zig");
const cpuid = @import("x86_64/cpuid.zig");
const std = @import("std");

pub const Error = error {
    UnknownVendor,
    VirtualizationDisabled,
    VirtualizationNotSupported
};

pub const Backend = union(enum) {
    // TODO(garrett): Add Intel variant
    amd: amd.Backend,

    pub fn prepareVirtualization(self: @This()) Error!void {
        return switch (self) {
            .amd => |backend| {
                if (!backend.isVirtualizationSupported()) return error.VirtualizationNotSupported;
                if (backend.isVirtualizationDisabled()) return error.VirtualizationDisabled;

                // TODO(garrett): Flesh out the rest of the virtualization steps
                @panic(
                    std.fmt.comptimePrint(
                        "Reached Unimplemented Code: {s}:{d}:{d} ({s})\r\n",
                        .{ @src().file, @src().line, @src().column, @src().fn_name }
                    )
                );
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
                .max_standard_func = basic_info.max_standard_func
            }
        };
    } else {
        return error.UnknownVendor;
    }
}
