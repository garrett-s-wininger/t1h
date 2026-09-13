const std = @import("std");

pub const SegmentSelector = packed struct(u16) {
    privilege_level: u2,
    table_selector: u1,
    table_index: u13,
};

pub const SegmentDescriptor = packed struct(u64) {
    const Flags = packed struct(u4) {
        reserved: u1,
        is_long_mode: u1,
        is_32_bit: u1,
        is_limit_in_page_granularity: u1,
    };

    limit_low: u16,
    base_low: u16,
    base_middle: u8,
    access: u8,
    limit_high: u4,
    flags: Flags,
    base_high: u8,

    pub fn base(self: @This()) u64 {
        return self.base_low | (@as(u64, self.base_middle) << 16) | (@as(u64, self.base_high) << 24);
    }

    pub fn limit(self: @This()) u32 {
        var result: u32 = self.limit_low | (@as(u32, self.limit_high) << 16);

        if (self.flags.is_limit_in_page_granularity != 0) {
            result = (result << 12 | 0xFFF);
        }

        return result;
    }
};

pub const DescriptorTable = struct {
    base_address: u64,
    entries: u16,

    pub fn descriptorAtIndex(self: @This(), index: u16) *align(1) SegmentDescriptor {
        if (index >= self.entries) {
            @panic("Requested out of bounds descriptor index, cannot load from table");
        }

        return @ptrFromInt(self.base_address + (index * @sizeOf(SegmentDescriptor)));
    }
};
