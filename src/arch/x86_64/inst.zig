pub const DescriptorTableRegister = packed struct(u80) {
    limit: u16,
    base: u64,
};

pub fn inb(port: u16) u8 {
    return asm volatile (
        \\inb %[port], %[result]
        : [result] "={al}" (-> u8),
        : [port] "{dx}" (port),
    );
}

pub fn outb(port: u16, value: u8) void {
    asm volatile (
        \\ outb %[value], %[port]
        :
        : [value] "{al}" (value),
          [port] "{dx}" (port),
    );
}

pub fn rdmsr(register: u32) u64 {
    var eax: u32 = undefined;
    var edx: u32 = undefined;

    asm volatile (
        \\rdmsr
        : [_] "={eax}" (eax),
          [_] "={edx}" (edx),
        : [register] "{ecx}" (register),
    );

    return (@as(u64, edx) << 32) | eax;
}

pub fn readCodeSegment() u16 {
    return asm volatile (
        \\movw %%cs, %[out]
        : [out] "={ax}" (-> u16),
    );
}

pub fn readCr0() u64 {
    return asm volatile (
        \\movq %%cr0, %[out]
        : [out] "={rax}" (-> u64),
    );
}

pub fn readCr3() u64 {
    return asm volatile (
        \\movq %%cr3, %[out]
        : [out] "={rax}" (-> u64),
    );
}

pub fn readCr4() u64 {
    return asm volatile (
        \\movq %%cr4, %[out]
        : [out] "={rax}" (-> u64),
    );
}

pub fn readDataSegment() u16 {
    return asm volatile (
        \\movw %%ds, %[out]
        : [out] "={ax}" (-> u16),
    );
}

pub fn readExtraSegment() u16 {
    return asm volatile (
        \\movw %%es, %[out]
        : [out] "={ax}" (-> u16),
    );
}

pub fn readFlags() u64 {
    return asm volatile (
        \\pushfq
        \\popq %[out]
        : [out] "={rax}" (-> u64),
        :
        : .{ .rsp = true });
}

pub fn readGlobalDescriptorTableRegister(address: *DescriptorTableRegister) void {
    var value: DescriptorTableRegister = undefined;

    asm volatile (
        \\sgdt %[value]
        : [value] "=m" (value),
    );

    address.* = value;
}

pub fn readInterruptDescriptorTableRegister(address: *DescriptorTableRegister) void {
    var value: DescriptorTableRegister = undefined;

    asm volatile (
        \\sidt %[value]
        : [value] "=m" (value),
    );

    address.* = value;
}

pub fn readStackPointer() u64 {
    return asm volatile (
        \\movq %%rsp, %[out]
        : [out] "={rax}" (-> u64),
    );
}

pub fn readStackSegment() u16 {
    return asm volatile (
        \\movw %%ss, %[out]
        : [out] "={ax}" (-> u16),
    );
}

pub fn writeCr3(value: u64) void {
    asm volatile (
        \\movq %[value], %%cr3
        :
        : [value] "{rax}" (value),
        : .{ .memory = true });
}

pub fn wrmsr(register: u32, value: u64) void {
    const low_order: u32 = @truncate(value);
    const high_order: u32 = @truncate(value >> 32);

    asm volatile (
        \\wrmsr
        :
        : [register] "{ecx}" (register),
          [high_order] "{edx}" (high_order),
          [low_order] "{eax}" (low_order),
    );
}
