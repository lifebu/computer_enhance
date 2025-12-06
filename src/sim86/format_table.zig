const std = @import("std");
const assert = std.debug.assert;
const def = @import("defines.zig");

// TODO: Rename to FieldUsage
pub const FieldType = enum {
    literal,
    mod, reg, rm,
    segment_reg, disp, data,

    has_disp, wide_disp,
    has_data, wide_for_data,
    wide_rm,
    jr_disp,
    reg_dest, sign, wide, v, z,
};
pub const FieldBits = struct {
    usage: FieldType,
    bit_count: u3,
    // TODO: What is shift here?
    shift: u3 = 0,
    value: ?u8 = null,
};
pub const Format = struct {
    operation: def.Operation,
    fields: []const FieldBits,
};

fn literal(bits: []const u8) FieldBits {
    const parsed: std.zig.number_literal.Result = std.zig.parseNumberLiteral("0b" ++ bits);
    comptime assert(parsed != .failure);
    return .{ .usage = .literal, .value = @intCast(parsed.int), .bit_count = bits.len };
}
const d: FieldBits = .{ .usage = .reg_dest, .bit_count = 1 }; 
const w: FieldBits = .{ .usage = .wide, .bit_count = 1 }; 
const mod: FieldBits = .{ .usage = .mod, .bit_count = 2 }; 
const reg: FieldBits = .{ .usage = .reg, .bit_count = 3 }; 
const rm: FieldBits = .{ .usage = .rm, .bit_count = 3 }; 

pub const Table = [_]Format{
    Format{ .operation = .mov, .fields = &.{ literal("100010"), d, w, mod, reg, rm } },
};
