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

const InterceptBlock1 = packed struct(u32) {
    _reserved1: u24,
    hlt: u1,
    _reserved2: u7,
};

const Segment = packed struct(u128) {
    selector: u16,
    attribute: u16,
    limit: u32,
    base: u64
};

const VmControlBlock = struct {
    const total_size = 4096;
    const saved_state_boundary = 0x400;

    raw: *[@This().total_size]u8,

    fn ptr(self: @This(), comptime offset: usize, comptime T: type) *T {
        comptime if ((offset + @sizeOf(T)) > @This().total_size) {
            @compileError("Requested offset/type would be outside of VMCB memory");
        };

        return @ptrCast(@alignCast(self.raw[offset..][0..@sizeOf(T)]));
    }

    fn savedStatePtr(self: @This(), comptime offset: usize, comptime T: type) *T {
        return self.ptr(offset + @This().saved_state_boundary, T);
    }

    fn asid(self: @This()) *u32 {
        return self.ptr(0x058, u32);
    }

    fn cpl(self: @This()) *u8 {
        return self.savedStatePtr(0x0CB, u8);
    }

    fn cr0(self: @This()) *u64 {
        return self.savedStatePtr(0x158, u64);
    }

    fn cr3(self: @This()) *u64 {
        return self.savedStatePtr(0x150, u64);
    }

    fn cr4(self: @This()) *u64 {
        return self.savedStatePtr(0x148, u64);
    }

    fn cs(self: @This()) *Segment {
        return self.savedStatePtr(0x010, Segment);
    }

    fn ds(self: @This()) *Segment {
        return self.savedStatePtr(0x030, Segment);
    }

    fn efer(self: @This()) *u64 {
        return self.savedStatePtr(0x0D0, u64);
    }

    fn es(self: @This()) *Segment {
        return self.savedStatePtr(0x000, Segment);
    }

    fn flags(self: @This()) *u64 {
        return self.savedStatePtr(0x170, u64);
    }

    fn gdtr(self: @This()) *Segment {
        return self.savedStatePtr(0x060, Segment);
    }

    fn idtr(self: @This()) *Segment {
        return self.savedStatePtr(0x080, Segment);
    }

    fn interceptBlock1(self: @This()) *InterceptBlock1 {
        return self.ptr(0x00C, InterceptBlock1);
    }

    fn rsp(self: @This()) *u64 {
        return self.savedStatePtr(0x1D8, u64);
    }

    fn ss(self: @This()) *Segment {
        return self.savedStatePtr(0x020, Segment);
    }
};

fn vmsave(save_address: u64) void {
    asm volatile(
        \\vmsave
        :
        : [save_address] "{rax}" (save_address)
    );
}

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
        const svm_enabled_efer = efer | svm_enable_bit;
        inst.wrmsr(efer_msr, svm_enabled_efer);

        const host_save_area: *[4096]u8 = @ptrFromInt(allocation_start_address);
        @memset(host_save_area, 0);
        inst.wrmsr(vm_host_save_address_msr, @intFromPtr(host_save_area));

        const vm_control_block_address: *[4096]u8 = @ptrFromInt(allocation_start_address + 4096);
        @memset(vm_control_block_address, 0);
        vmsave(@intFromPtr(vm_control_block_address));
        const vmcb: VmControlBlock = .{ .raw = vm_control_block_address };

        vmcb.asid().* = 1;
        vmcb.interceptBlock1().*.hlt = 1;
        vmcb.efer().* = svm_enabled_efer;
        vmcb.cpl().* = 0;
        vmcb.cr0().* = inst.readCr0();
        vmcb.cr3().* = inst.readCr3();
        vmcb.cr4().* = inst.readCr4();
        vmcb.flags().* = inst.readFlags();
        vmcb.rsp().* = inst.readStackPointer();

        var gdtr: inst.DescriptorTableRegister = undefined;
        inst.readGlobalDescriptorTableRegister(&gdtr);

        vmcb.gdtr().* = .{
            .selector = 0,
            .attribute = 0,
            .limit = gdtr.limit,
            .base = gdtr.base
        };

        var idtr: inst.DescriptorTableRegister = undefined;
        inst.readInterruptDescriptorTableRegister(&idtr);

        vmcb.idtr().* = .{
            .selector = 0,
            .attribute = 0,
            .limit = idtr.limit,
            .base = idtr.base
        };

        // TODO(garrett): Configure segment selectors.
        // TODO(garrett): Configure RIP of guest VM.
        // TODO(garrett): Launch via VMRUN.

        @panic(
            std.fmt.comptimePrint(
                "Reached Unimplemented Code: {s}:{d}:{d} ({s})\r\n",
                .{ @src().file, @src().line, @src().column, @src().fn_name }
            )
        );
    }
};
