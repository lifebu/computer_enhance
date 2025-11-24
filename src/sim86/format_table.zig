const std = @import("std");
const def = @import("defines.zig");

// TODO: format should be in it's own file! But where to put operation?
pub const Format = struct {
    operation: def.Operation,
    // TODO: casey has an array of 16 bits each with an enum (which kind), bitcount, shift (?) and value.
    literal: ?u8 = null,
};
pub const Table: []Format = blk: {
    var result = [256]Format{};
    result[0] = Format{ .opcode = .mov };
    break :blk result;
};
