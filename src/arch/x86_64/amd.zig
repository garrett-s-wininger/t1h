const cpuid = @import("cpuid.zig");
const inst = @import("inst.zig");
const std = @import("std");

pub const vendor_string = "AuthenticAMD";

const processor_model_and_feature_ids = 0x0000_0001;
const msr_feature_bit = (1 << 5);

const extended_processor_feature_ids = 0x8000_0001;
const svm_feature_bit = (1 << 2);

const vm_cr_msr = 0xC001_0114;
const svm_disabled_bit = (1 << 4);

const efer_msr = 0xC000_0080;
const svm_enable_bit = (1 << 12);

const vm_host_save_address_msr = 0xC001_0117;

pub const Backend = struct {
    max_standard_func: u32,
    max_extended_func: u32,

    pub fn isVirtualizationDisabled(_: @This()) bool {
        const vm_cr = inst.rdmsr(vm_cr_msr);
        return (vm_cr & svm_disabled_bit) != 0;
    }

    pub fn isVirtualizationSupported(self: @This()) bool {
        if (self.max_standard_func < processor_model_and_feature_ids) return false;

        const standard_feature_information = cpuid.query(processor_model_and_feature_ids, 0);
        const msr_enabled = (standard_feature_information.edx & msr_feature_bit) != 0;

        if (!msr_enabled) return false;
        if (self.max_extended_func < extended_processor_feature_ids) return false;

        const extended_feature_information = cpuid.query(extended_processor_feature_ids, 0);
        const svm_enabled = (extended_feature_information.ecx & svm_feature_bit) != 0;

        return svm_enabled;
    }

    pub fn prepareVirtualization(_: @This(), allocation_start_address: u64) void {
        const efer = inst.rdmsr(efer_msr);
        inst.wrmsr(efer_msr, efer | svm_enable_bit);

        const host_save_area: *[4096]u8 = @ptrFromInt(allocation_start_address);
        @memset(host_save_area, 0);
        inst.wrmsr(vm_host_save_address_msr, @intFromPtr(host_save_area));

        // TODO(garrett): Flesh out the rest of the virtualization steps
        @panic(
            std.fmt.comptimePrint(
                "Reached Unimplemented Code: {s}:{d}:{d} ({s})\r\n",
                .{ @src().file, @src().line, @src().column, @src().fn_name }
            )
        );
    }
};
