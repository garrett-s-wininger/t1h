const logging = @import("../logging.zig");
const std = @import("std");
const uefi = std.os.uefi;

const cpuid = struct {
    const Result = struct {
        eax: u32,
        ebx: u32,
        ecx: u32,
        edx: u32
    };

    fn query(leaf: u32, subleaf: u32) Result {
        var eax: u32 = undefined;
        var ebx: u32 = undefined;
        var ecx: u32 = undefined;
        var edx: u32 = undefined;

        asm volatile(
            \\cpuid
            : [_] "={eax}" (eax), [_] "={ebx}" (ebx), [_] "={ecx}" (ecx), [_] "={edx}" (edx),
            : [leaf] "{eax}" (leaf), [subleaf] "{ecx}" (subleaf)
        );

        return .{
            .eax = eax,
            .ebx = ebx,
            .ecx = ecx,
            .edx = edx,
        };
    }
};

pub fn is_virtualization_supported() uefi.Error!bool {
    var vendor: [12]u8 = undefined;
    const basic_info = cpuid.query(0, 0);

    @memcpy(vendor[0..4], std.mem.asBytes(&basic_info.ebx));
    @memcpy(vendor[4..8], std.mem.asBytes(&basic_info.edx));
    @memcpy(vendor[8..12], std.mem.asBytes(&basic_info.ecx));

    try logging.log("");
    try logging.log("CPU Detection");
    try logging.log("=============\r\n");

    try logging.logFormatted(
        "Vendor: {s}",
        .{vendor[0..12]}
    );

    try logging.log("");

    return false;
}
