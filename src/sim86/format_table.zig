const std = @import("std");
const assert = std.debug.assert;
const def = @import("defines.zig");

pub const FieldUsage = enum {
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
    usage: FieldUsage,
    bit_count: u3,
    // TODO: What is shift here?
    shift: u3 = 0,
    value: ?u8 = null,
};
pub const Format = struct {
    operation: def.Operation,
    fields: []const FieldBits,
};

fn literal(bits: []const u8, required: bool, usage: FieldUsage) FieldBits {
    const parsed: std.zig.number_literal.Result = std.zig.parseNumberLiteral("0b" ++ bits);
    comptime assert(parsed != .failure);
    const bit_count: u8 = if(required) bits.len else 0;
    return .{ .usage = usage, .bit_count = bit_count, .shift = 0, .value = @intCast(parsed.int) };
}
fn lit(bits: []const u8) FieldBits {
    return literal(bits, true, .literal);
}
fn litW(bits: []const u8) FieldBits {
    assert(bits.len == 1);
    return literal(bits, false, .w);
}
fn litReg(bits: []const u8) FieldBits {
    assert(bits.len == 3);
    return literal(bits, false, .reg);
}
fn litMod(bits: []const u8) FieldBits {
    assert(bits.len == 2);
    return literal(bits, false, .mod);
}
fn litRM(bits: []const u8) FieldBits {
    assert(bits.len == 3);
    return literal(bits, false, .rm);
}
fn litD(bits: []const u8) FieldBits {
    assert(bits.len == 1);
    return literal(bits, false, .reg_dest);
}
fn litS(bits: []const u8) FieldBits {
    assert(bits.len == 1);
    return literal(bits, false, .sign);
}
fn flags(usage: FieldUsage) FieldBits {
    return literal("1", false, usage);
}

const d: FieldBits = .{ .usage = .reg_dest, .bit_count = 1 }; 
const s: FieldBits = .{ .usage = .sign, .bit_count = 1 };
const w: FieldBits = .{ .usage = .wide, .bit_count = 1 }; 
const v: FieldBits = .{ .usage = .v, .bit_count = 1 }; 
const z: FieldBits = .{ .usage = .z, .bit_count = 1 }; 

const xxx: FieldBits = .{ .usage = .data, .bit_count = 3, .shift = 0 }; 
const yyy: FieldBits = .{ .usage = .data, .bit_count = 3, .shift = 3 }; 
const rm: FieldBits = .{ .usage = .rm, .bit_count = 3 }; 
const mod: FieldBits = .{ .usage = .mod, .bit_count = 2 }; 
const reg: FieldBits = .{ .usage = .reg, .bit_count = 3 }; 
const sr: FieldBits = .{ .usage = .segment_reg, .bit_count = 2 }; 

const disp: FieldBits = .{ .usage = .has_disp, .bit_count = 0, .shift = 0, .value = 1 };
const addr_low: FieldBits = .{ .usage = .has_disp, .bit_count = 0, .shift = 0, .value = 1 };
const addr_high: FieldBits = .{ .usage = .wide_disp, .bit_count = 0, .shift = 0, .value = 1 };
const data: FieldBits = .{ .usage = .has_data, .bit_count = 0, .shift = 0, .value = 1 };
const data_wide: FieldBits = .{ .usage = .wide_for_data, .bit_count = 0, .shift = 0, .value = 1 };

pub const Table = [_]Format{
    Format{ .operation = .mov, .fields = &.{ lit("100010"), d, w, mod, reg, rm } },
    Format{ .operation = .mov, .fields = &.{ lit("1100011"), w, mod, lit("000"), rm, data, data_wide, litD("0") } },
    Format{ .operation = .mov, .fields = &.{ lit("1011"), w, reg, data, data_wide, litD("1") } },
    Format{ .operation = .mov, .fields = &.{ lit("1010000"), w, addr_low, addr_high, litReg("000"), litMod("00"), litRM("110"), litD("1") } },
    Format{ .operation = .mov, .fields = &.{ lit("1010001"), w, addr_low, addr_high, litReg("000"), litMod("00"), litRM("110"), litD("0") } },
};
