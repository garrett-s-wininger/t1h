// TODO(garrett): Register access is x86_64 port I/O today.
// Some platforms (e.g. ARM) use MMIO instead so we need to
// abstract the read/write paths.

// TODO(garrett): This driver assumes a 16550-compatible
// register layout. Other common UARTs need their own
// handling.

const inst = @import("../arch/x86_64/inst.zig");

pub const com1: u16 = 0x3F8;

const interrupt_offset = 1;
const fifo_control_offset = 2;
const line_control_offset = 3;
const modem_control_offset = 4;
const line_status_offset = 5;

const FifoControl = packed struct(u8) {
    enabled: u1,
    clear_rx: u1,
    clear_tx: u1,
    dma_selection: u1,
    reserved: u2,
    interrupt_level: u2
};

const interrupt_trigger_level = enum(u2) {
    byte1 = 0b00,
    bytes4 = 0b01,
    bytes8 = 0b10,
    bytes14 = 0b11
};

const data_configuration = enum(u2) {
    bits5 = 0b00,
    bits6 = 0b01,
    bits7 = 0b10,
    bits8 = 0b11
};

const LineControl = packed struct(u8) {
    data: u2,
    stop: u1,
    parity: u3,
    is_break_enabled: u1,
    is_divisor_latch_enabled: u1
};

const LineStatus = packed struct(u8) {
    data_ready: u1,
    overrun_error: u1,
    parity_error: u1,
    framing_error: u1,
    break_indicator: u1,
    transmission_buffer_empty: u1,
    transmitter_empty: u1,
    impending_error: u1
};

const ModemControl = packed struct(u8) {
    data_terminal_ready: u1,
    request_to_send: u1,
    out1: u1,
    out2: u1,
    loop: u1,
    reserved1: u1,
    reserved2: u1,
    reserved3: u1
};

fn configure_8n1(port_base: u16) void {
    const configuration = LineControl{
        .data = @intFromEnum(data_configuration.bits8),
        .stop = 0,
        .parity = 0,
        .is_break_enabled = 0,
        .is_divisor_latch_enabled = 0
    };

    inst.outb(port_base + line_control_offset, @bitCast(configuration));
}

fn configure_fifo(port_base: u16) void {
    const configuration = FifoControl{
        .enabled = 1,
        .clear_rx = 1,
        .clear_tx = 1,
        .dma_selection = 0,
        .reserved = 0,
        .interrupt_level = @intFromEnum(interrupt_trigger_level.bytes14)
    };

    inst.outb(port_base + fifo_control_offset, @bitCast(configuration));
}

fn configure_modem_control(port_base: u16) void {
    const configuration = ModemControl{
        .data_terminal_ready = 1,
        .request_to_send = 1,
        .out1 = 0,
        .out2 = 1,
        .loop = 0,
        .reserved1 = 0,
        .reserved2 = 0,
        .reserved3 = 0
    };

    inst.outb(port_base + modem_control_offset, @bitCast(configuration));
}

fn disable_interrupts(port_base: u16) void {
    inst.outb(port_base + interrupt_offset, 0);
}

fn enable_divisor_latch(port_base: u16) void {
    const configuration = LineControl{
        .data = 0,
        .stop = 0,
        .parity = 0,
        .is_break_enabled = 0,
        .is_divisor_latch_enabled = 1
    };

    inst.outb(port_base + line_control_offset, @bitCast(configuration));
}

fn set_divisor(port_base: u16, divisor: u16) void {
    inst.outb(port_base, @truncate(divisor));
    inst.outb(port_base + interrupt_offset, @truncate(divisor >> 8));
}

pub fn init(port_base: u16) void {
    disable_interrupts(port_base);
    enable_divisor_latch(port_base);
    set_divisor(port_base, 1);
    configure_8n1(port_base);
    configure_fifo(port_base);
    configure_modem_control(port_base);

    // TODO(garrett): Probe for device presence and fail soft if nothing is there
    // to avoid spinning forever in transmission calls.
}

pub fn putc(port_base: u16, char: u8) void {
    var status: LineStatus = undefined;

    while(true) {
        status = @bitCast(inst.inb(port_base + line_status_offset));
        if (status.transmission_buffer_empty == 1) break;
    }

    inst.outb(port_base, char);
}
