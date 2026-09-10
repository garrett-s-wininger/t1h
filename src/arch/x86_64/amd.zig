const cpuid = @import("cpuid.zig");
const gdt = @import("gdt.zig");
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

const InterceptBlock2 = packed struct(u32) {
    vmrun: u1,
    _reserved: u31
};

const Segment = packed struct(u128) {
    selector: u16,
    attribute: u16,
    limit: u32,
    base: u64
};

const VirtualMachineControlBlock = struct {
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

    fn attributeFromSegmentDescriptor(descriptor: gdt.SegmentDescriptor) u16 {
        const segment_flags: u4 = @bitCast(descriptor.flags);
        return descriptor.access | (@as(u16, segment_flags) << 8);
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

    fn exit_code(self: @This()) *u64 {
        return self.ptr(0x070, u64);
    }

    fn fillFromCurrentCpu(self: @This(), efer_override: u64) void {
        vmsave(@intFromPtr(self.raw));

        self.asid().* = 1;
        self.interceptBlock1().*.hlt = 1;
        self.interceptBlock2().*.vmrun = 1;
        self.efer().* = efer_override;
        self.cpl().* = 0;
        self.cr0().* = inst.readCr0();
        self.cr3().* = inst.readCr3();
        self.cr4().* = inst.readCr4();
        self.flags().* = inst.readFlags();
        self.rsp().* = inst.readStackPointer();

        var gdt_register: inst.DescriptorTableRegister = undefined;
        inst.readGlobalDescriptorTableRegister(&gdt_register);

        self.gdtr().* = .{
            .selector = 0,
            .attribute = 0,
            .limit = gdt_register.limit,
            .base = gdt_register.base
        };

        const descriptor_table = gdt.DescriptorTable{
            .base_address = gdt_register.base,
            .entries = (gdt_register.limit + 1) / @sizeOf(gdt.SegmentDescriptor)
        };

        const code_segment_selector: gdt.SegmentSelector = @bitCast(inst.readCodeSegment());
        const data_segment_selector: gdt.SegmentSelector = @bitCast(inst.readDataSegment());
        const extra_segment_selector: gdt.SegmentSelector = @bitCast(inst.readExtraSegment());
        const stack_segment_selector: gdt.SegmentSelector = @bitCast(inst.readStackSegment());
        const selectors = [_]gdt.SegmentSelector{
            code_segment_selector,
            data_segment_selector,
            extra_segment_selector,
            stack_segment_selector
        };

        for (selectors) |selector| {
            if (selector.table_selector == 1) {
                @panic("Encountered selector for local descriptor, rather than global");
            }
        }

        fillSegment(self.cs(), descriptor_table, code_segment_selector);
        fillSegment(self.ds(), descriptor_table, data_segment_selector);
        fillSegment(self.es(), descriptor_table, extra_segment_selector);
        fillSegment(self.ss(), descriptor_table, stack_segment_selector);

        var idt_register: inst.DescriptorTableRegister = undefined;
        inst.readInterruptDescriptorTableRegister(&idt_register);

        self.idtr().* = .{
            .selector = 0,
            .attribute = 0,
            .limit = idt_register.limit,
            .base = idt_register.base
        };
    }

    fn fillSegment(segment_address: *Segment, descriptor_table: gdt.DescriptorTable, segment_selector: gdt.SegmentSelector) void {
        const segment_descriptor = descriptor_table.descriptorAtIndex(segment_selector.table_index);

        segment_address.* = Segment{
            .selector = @bitCast(segment_selector),
            .attribute = attributeFromSegmentDescriptor(segment_descriptor.*),
            .limit = segment_descriptor.limit(),
            .base = segment_descriptor.base()
        };
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

    fn interceptBlock2(self: @This()) *InterceptBlock2 {
        return self.ptr(0x010, InterceptBlock2);
    }

    fn rip(self: @This()) *u64 {
        return self.savedStatePtr(0x178, u64);
    }

    fn rsp(self: @This()) *u64 {
        return self.savedStatePtr(0x1D8, u64);
    }

    fn ss(self: @This()) *Segment {
        return self.savedStatePtr(0x020, Segment);
    }
};

fn guestHlt() callconv(.naked) noreturn {
    asm volatile("hlt");
}

fn vmrun(vmcb_address: u64) void {
    asm volatile(
        \\vmrun
        :
        : [vmcb_address] "{rax}" (vmcb_address)
        : .{ .memory = true }
    );
}

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
    vmcb: ?VirtualMachineControlBlock = null,

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

    pub fn prepareVirtualization(self: *@This(), allocation_start_address: u64) void {
        const efer = inst.rdmsr(efer_msr);
        const svm_enabled_efer = efer | svm_enable_bit;
        inst.wrmsr(efer_msr, svm_enabled_efer);

        const host_save_area: *[4096]u8 = @ptrFromInt(allocation_start_address);
        @memset(host_save_area, 0);
        inst.wrmsr(vm_host_save_address_msr, @intFromPtr(host_save_area));

        const vm_control_block_address: *[4096]u8 = @ptrFromInt(allocation_start_address + 4096);
        @memset(vm_control_block_address, 0);

        const control_block: VirtualMachineControlBlock = .{ .raw = vm_control_block_address };
        control_block.fillFromCurrentCpu(svm_enabled_efer);
        control_block.rip().* = @intFromPtr(&guestHlt);
        self.vmcb = control_block;
    }

    pub fn runGuest(self: @This()) u64 {
        const vmcb = self.vmcb orelse @panic("VMCB not prepared");
        vmrun(@intFromPtr(vmcb.raw));

        return vmcb.exit_code().*;
    }
};
