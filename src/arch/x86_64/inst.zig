pub fn rdmsr(register: u32) u64 {
    var eax: u32 = undefined;
    var edx: u32 = undefined;

    asm volatile(
        \\rdmsr
        : [_] "={eax}" (eax), [_] "={edx}" (edx)
        : [register] "{ecx}" (register)
    );

    return (@as(u64, edx) << 32) | eax;
}

pub fn wrmsr(register: u32, value: u64) void {
    const low_order: u32 = @truncate(value);
    const high_order: u32 = @truncate(value >> 32);

    asm volatile(
        \\wrmsr
        :
        : [register] "{ecx}" (register), [high_order] "{edx}" (high_order), [low_order] "{eax}" (low_order)
    );
}
