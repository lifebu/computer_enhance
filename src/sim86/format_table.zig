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
// TODO: Have a better name for bits that are not part of the bits stream, just for our formatting.
// TODO: always use string literals?
fn implD(value: u1) FieldBits {
    return .{ .usage = .reg_dest, .bit_count = 0, .shift = 0, .value = value };
}
fn implReg(value: u3) FieldBits {
    return .{ .usage = .reg, .bit_count = 0, .shift = 0, .value = value };
}
fn implMod(value: u2) FieldBits {
    return .{ .usage = .mod, .bit_count = 0, .shift = 0, .value = value };
}
fn implRM(value: u3) FieldBits {
    return .{ .usage = .rm, .bit_count = 0, .shift = 0, .value = value };
}
const d: FieldBits = .{ .usage = .reg_dest, .bit_count = 1 }; 
const w: FieldBits = .{ .usage = .wide, .bit_count = 1 }; 
const mod: FieldBits = .{ .usage = .mod, .bit_count = 2 }; 
const reg: FieldBits = .{ .usage = .reg, .bit_count = 3 }; 
const rm: FieldBits = .{ .usage = .rm, .bit_count = 3 }; 
const addr_low: FieldBits = .{ .usage = .has_disp, .bit_count = 0, .shift = 0, .value = 1 };
const addr_high: FieldBits = .{ .usage = .wide_disp, .bit_count = 0, .shift = 0, .value = 1 };
const data: FieldBits = .{ .usage = .has_data, .bit_count = 0, .shift = 0, .value = 1 };
const data_wide: FieldBits = .{ .usage = .wide_for_data, .bit_count = 0, .shift = 0, .value = 1 };

pub const Table = [_]Format{
    Format{ .operation = .mov, .fields = &.{ literal("100010"), d, w, mod, reg, rm } },
    Format{ .operation = .mov, .fields = &.{ literal("1100011"), w, mod, literal("000"), rm, data, data_wide, implD(0) } },
    Format{ .operation = .mov, .fields = &.{ literal("1011"), w, reg, data, data_wide, implD(1) } },
    Format{ .operation = .mov, .fields = &.{ literal("1010000"), w, addr_low, addr_high, implReg(0), implMod(0), implRM(0b110), implD(1) } },
    Format{ .operation = .mov, .fields = &.{ literal("1010001"), w, addr_low, addr_high, implReg(0), implMod(0), implRM(0b110), implD(0) } },
};
