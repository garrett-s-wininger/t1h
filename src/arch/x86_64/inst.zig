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
