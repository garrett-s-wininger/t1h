const inst = @import("inst.zig");

pub const com1: u16 = 0x3F8;

pub const PortMapped = struct {
    base: u16,

    pub fn read(self: *const @This(), offset: u16) u8 {
        return inst.inb(self.base + offset);
    }

    pub fn write(self: *const @This(), offset: u16, value: u8) void {
        inst.outb(self.base + offset, value);
    }
};
