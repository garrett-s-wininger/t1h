const logging = @import("../logging.zig");
const std = @import("std");
const uefi = std.os.uefi;

pub fn is_virtualization_supported() uefi.Error!bool {
    try logging.logFormatted("[TODO] {s}", .{"Remove me, we're validating logging."});
    return false;
}
