pub const vendor_string = "AuthenticAMD";
const extended_processor_feature_ids = 0x8000_0001;

pub const Backend = struct {
    max_standard_func: u32,
    max_extended_func: u32,

    pub fn isVirtualizationSupported(self: @This()) bool {
        if (self.max_extended_func < extended_processor_feature_ids) {
            return false;
        }

        return true;
    }
};
