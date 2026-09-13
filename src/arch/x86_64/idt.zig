pub const InterruptAndTrapGate = packed struct(u128) {
    offset_low: u16,
    selector: u16,
    interrupt_stack_table: u3,
    reserved1: u5,
    type: u4,
    must_be_zero: u1,
    descriptor_privilege_level: u2,
    present: u1,
    offset_mid: u16,
    offset_high: u32,
    reserved2: u32,
};

pub fn gateForAddress(selector: u16, address: u64) InterruptAndTrapGate {
    const interrupt_type: u4 = 0xE;

    return .{
        .offset_low = @truncate(address),
        .selector = selector,
        .interrupt_stack_table = 0,
        .reserved1 = 0,
        .type = interrupt_type,
        .must_be_zero = 0,
        .descriptor_privilege_level = 0,
        .present = 1,
        .offset_mid = @truncate(address >> 16),
        .offset_high = @truncate(address >> 32),
        .reserved2 = 0,
    };
}

pub const InterruptDescriptorTable = [256]InterruptAndTrapGate;
