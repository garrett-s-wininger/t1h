const cpuid = @import("cpuid.zig");
const inst = @import("inst.zig");

pub const vendor_string = "AuthenticAMD";

const processor_model_and_feature_ids = 0x0000_0001;
const msr_feature_bit = (1 << 5);

const extended_processor_feature_ids = 0x8000_0001;
const svm_feature_bit = (1 << 2);

const vm_cr_msr = 0xC001_0114;
const svm_disabled_bit = (1 << 4);

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
};
