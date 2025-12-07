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
    bit_count: u4,
    // TODO: What is shift here?
    shift: u3 = 0,
    value: ?u8 = null,
};
pub const Format = struct {
    operation: def.Operation,
    fields: []const FieldBits,
};

fn literal(bits: []const u8, required: bool, usage: FieldUsage) FieldBits {
    @setEvalBranchQuota(2500);
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
    return literal(bits, false, .wide);
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
    Format{ .operation = .mov, .fields = &.{ lit("100011"), d, lit("0"), mod, lit("0"), sr, rm } },

    Format{ .operation = .push, .fields = &.{ lit("11111111"), mod, lit("110"), rm, litW("1") } },
    Format{ .operation = .push, .fields = &.{ lit("01010"), reg, litW("1") } },
    Format{ .operation = .push, .fields = &.{ lit("000"), sr, lit("110"), litW("1") } },

    Format{ .operation = .pop, .fields = &.{ lit("10001111"), mod, lit("000"), rm, litW("1") } },
    Format{ .operation = .pop, .fields = &.{ lit("01011"), reg, litW("1") } },
    Format{ .operation = .pop, .fields = &.{ lit("000"), sr, lit("111"), litW("1") } },

    Format{ .operation = .xchg, .fields = &.{ lit("1000011"), w, mod, reg, rm, litD("1") } },
    Format{ .operation = .xchg, .fields = &.{ lit("10010"), reg, litMod("11"), litW("1"), litRM("000") } },

    Format{ .operation = .in, .fields = &.{ lit("1110010"), w, data, litReg("000"), litD("1")} },
    Format{ .operation = .in, .fields = &.{ lit("1110110"), w, litReg("000"), litD("1"), litMod("11"), litRM("010"), flags(.wide_rm)} },
    Format{ .operation = .out, .fields = &.{ lit("1110011"), w, data, litReg("000"), litD("0")} },
    Format{ .operation = .out, .fields = &.{ lit("1110111"), w, litReg("000"), litD("0"), litMod("11"), litRM("010"), flags(.wide_rm)} },

    Format{ .operation = .add, .fields = &.{ lit("000000"), d, w, mod, reg, rm } },
    Format{ .operation = .add, .fields = &.{ lit("100000"), s, w, mod, lit("000"), rm, data, data_wide } },
    Format{ .operation = .add, .fields = &.{ lit("0000010"), w, data, data_wide, litReg("000"), litD("1") } },

    Format{ .operation = .adc, .fields = &.{ lit("000100"), d, w, mod, reg, rm } },
    Format{ .operation = .adc, .fields = &.{ lit("100000"), s, w, mod, lit("010"), rm, data, data_wide } },
    Format{ .operation = .adc, .fields = &.{ lit("0001010"), w, data, data_wide, litReg("000"), litD("1") } },

    Format{ .operation = .inc, .fields = &.{ lit("1111111"), w, mod, lit("000"), rm } },
    Format{ .operation = .inc, .fields = &.{ lit("01000"), reg, litW("1") } },

    Format{ .operation = .aaa, .fields = &.{ lit("00110111") } },
    Format{ .operation = .daa, .fields = &.{ lit("00100111") } },

    Format{ .operation = .sub, .fields = &.{ lit("001010"), d, w, mod, reg, rm } },
    Format{ .operation = .sub, .fields = &.{ lit("100000"), s, w, mod, lit("101"), rm, data, data_wide } },
    Format{ .operation = .sub, .fields = &.{ lit("0010110"), w, data, data_wide, litReg("000"), litD("1") } },

    Format{ .operation = .sbb, .fields = &.{ lit("000110"), d, w, mod, reg, rm } },
    Format{ .operation = .sbb, .fields = &.{ lit("100000"), s, w, mod, lit("011"), rm, data, data_wide } },
    Format{ .operation = .sbb, .fields = &.{ lit("0001110"), w, data, data_wide, litReg("000"), litD("1") } },

    Format{ .operation = .dec, .fields = &.{ lit("1111111"), w, mod, lit("001"), rm } },
    Format{ .operation = .dec, .fields = &.{ lit("01001"), reg, litW("1") } },

    Format{ .operation = .neg, .fields = &.{ lit("1111011"), w, mod, lit("011"), rm } },

    Format{ .operation = .cmp, .fields = &.{ lit("001110"), d, w, mod, reg, rm } },
    Format{ .operation = .cmp, .fields = &.{ lit("100000"), s, w, mod, lit("111"), rm, data, data_wide } },
    Format{ .operation = .cmp, .fields = &.{ lit("0011110"), w, data, data_wide, litReg("000"), litD("1") } },

    Format{ .operation = .aas, .fields = &.{ lit("00111111") } },
    Format{ .operation = .das, .fields = &.{ lit("00101111") } },
    Format{ .operation = .mul, .fields = &.{ lit("1111011"), w, mod, lit("100"), rm, litS("0") } },
    Format{ .operation = .imul, .fields = &.{ lit("1111011"), w, mod, lit("101"), rm, litS("1") } },
    Format{ .operation = .aam, .fields = &.{ lit("11010100"), lit("00001010") } },
    Format{ .operation = .div, .fields = &.{ lit("1111011"), w, mod, lit("110"), rm, litS("0") } },
    Format{ .operation = .idiv, .fields = &.{ lit("1111011"), w, mod, lit("111"), rm, litS("1") } },
    Format{ .operation = .aad, .fields = &.{ lit("11010101"), lit("00001010") } },
    Format{ .operation = .cbw, .fields = &.{ lit("10011000") } },
    Format{ .operation = .cwd, .fields = &.{ lit("10011001") } },

    Format{ .operation = .not, .fields = &.{ lit("1111011"), w, mod, lit("010"), rm } },
    Format{ .operation = .shl, .fields = &.{ lit("110100"), v, w, mod, lit("100"), rm } },
    Format{ .operation = .shr, .fields = &.{ lit("110100"), v, w, mod, lit("101"), rm } },
    Format{ .operation = .sar, .fields = &.{ lit("110100"), v, w, mod, lit("111"), rm } },
    Format{ .operation = .rol, .fields = &.{ lit("110100"), v, w, mod, lit("000"), rm } },
    Format{ .operation = .ror, .fields = &.{ lit("110100"), v, w, mod, lit("001"), rm } },
    Format{ .operation = .rcl, .fields = &.{ lit("110100"), v, w, mod, lit("010"), rm } },
    Format{ .operation = .rcr, .fields = &.{ lit("110100"), v, w, mod, lit("011"), rm } },

    Format{ .operation = .@"and", .fields = &.{ lit("001000"), d, w, mod, reg, rm } },
    Format{ .operation = .@"and", .fields = &.{ lit("1000000"), w, mod, lit("100"), rm, data, data_wide } },
    Format{ .operation = .@"and", .fields = &.{ lit("0010010"), w, data, data_wide, litReg("000"), litD("1") } },

    Format{ .operation = .@"test", .fields = &.{ lit("100001"), d, w, mod, reg, rm } },
    Format{ .operation = .@"test", .fields = &.{ lit("1111011"), w, mod, lit("000"), rm, data, data_wide } },
    Format{ .operation = .@"test", .fields = &.{ lit("1010100"), w, data, data_wide, litReg("000"), litD("1") } },

    Format{ .operation = .@"or", .fields = &.{ lit("000010"), d, w, mod, reg, rm } },
    Format{ .operation = .@"or", .fields = &.{ lit("1000000"), w, mod, lit("001"), rm, data, data_wide } },
    Format{ .operation = .@"or", .fields = &.{ lit("0000110"), w, data, data_wide, litReg("000"), litD("1") } },

    Format{ .operation = .xor, .fields = &.{ lit("001100"), d, w, mod, reg, rm } },
    Format{ .operation = .xor, .fields = &.{ lit("1000000"), w, mod, lit("110"), rm, data, data_wide } },
    Format{ .operation = .xor, .fields = &.{ lit("0011010"), w, data, data_wide, litReg("000"), litD("1") } },

    Format{ .operation = .rep, .fields = &.{ lit("1111001"), z } },
    Format{ .operation = .movs, .fields = &.{ lit("1010010"), w } },
    Format{ .operation = .cmps, .fields = &.{ lit("1010011"), w } },
    Format{ .operation = .scas, .fields = &.{ lit("1010111"), w } },
    Format{ .operation = .lods, .fields = &.{ lit("1010110"), w } },
    Format{ .operation = .stos, .fields = &.{ lit("1010101"), w } },

    Format{ .operation = .call, .fields = &.{ lit("11101000"), addr_low, addr_high} },
    Format{ .operation = .call, .fields = &.{ lit("11111111"), mod, lit("010"), rm, litW("1") } },
    Format{ .operation = .call, .fields = &.{ lit("10011010"), addr_low, addr_high, data, litW("1") } },
    Format{ .operation = .call, .fields = &.{ lit("11111111"), mod, lit("011"), rm, litW("1") } },

    Format{ .operation = .jmp, .fields = &.{ lit("11101001"), addr_low, addr_high} },
    Format{ .operation = .jmp, .fields = &.{ lit("11101011"), disp} },
    Format{ .operation = .jmp, .fields = &.{ lit("11111111"), mod, lit("100"), rm, litW("1") } },
    Format{ .operation = .jmp, .fields = &.{ lit("11101010"), addr_low, addr_high, data, litW("1") } },
    Format{ .operation = .jmp, .fields = &.{ lit("11111111"), mod, lit("101"), rm, litW("1") } },

    Format{ .operation = .ret, .fields = &.{ lit("11000011") } },
    Format{ .operation = .ret, .fields = &.{ lit("11000010"), data, data_wide, litW("1") } },
    Format{ .operation = .ret, .fields = &.{ lit("11001011") } },
    Format{ .operation = .ret, .fields = &.{ lit("11001010"), data, data_wide, litW("1") } },

    Format{ .operation = .je, .fields = &.{ lit("01110100"), disp, flags(.jr_disp) } },
    Format{ .operation = .jl, .fields = &.{ lit("01111100"), disp, flags(.jr_disp) } },
    Format{ .operation = .jle, .fields = &.{ lit("01111110"), disp, flags(.jr_disp) } },
    Format{ .operation = .jb, .fields = &.{ lit("01110010"), disp, flags(.jr_disp) } },
    Format{ .operation = .jbe, .fields = &.{ lit("01110110"), disp, flags(.jr_disp) } },
    Format{ .operation = .jp, .fields = &.{ lit("01111010"), disp, flags(.jr_disp) } },
    Format{ .operation = .jo, .fields = &.{ lit("01110000"), disp, flags(.jr_disp) } },
    Format{ .operation = .js, .fields = &.{ lit("01111000"), disp, flags(.jr_disp) } },
    Format{ .operation = .jne, .fields = &.{ lit("01110101"), disp, flags(.jr_disp) } },
    Format{ .operation = .jnl, .fields = &.{ lit("01111101"), disp, flags(.jr_disp) } },
    Format{ .operation = .jg, .fields = &.{ lit("01111111"), disp, flags(.jr_disp) } },
    Format{ .operation = .jnb, .fields = &.{ lit("01110011"), disp, flags(.jr_disp) } },
    Format{ .operation = .ja, .fields = &.{ lit("01110111"), disp, flags(.jr_disp) } },
    Format{ .operation = .jnp, .fields = &.{ lit("01111011"), disp, flags(.jr_disp) } },
    Format{ .operation = .jno, .fields = &.{ lit("01110001"), disp, flags(.jr_disp) } },
    Format{ .operation = .jns, .fields = &.{ lit("01111001"), disp, flags(.jr_disp) } },
    Format{ .operation = .loop, .fields = &.{ lit("11100010"), disp, flags(.jr_disp) } },
    Format{ .operation = .loopz, .fields = &.{ lit("11100001"), disp, flags(.jr_disp) } },
    Format{ .operation = .loopnz, .fields = &.{ lit("11100000"), disp, flags(.jr_disp) } },
    Format{ .operation = .jcxz, .fields = &.{ lit("11100011"), disp, flags(.jr_disp) } },

    Format{ .operation = .int, .fields = &.{ lit("11001101"), data } },
    Format{ .operation = .int3, .fields = &.{ lit("11001100") } },

    Format{ .operation = .into, .fields = &.{ lit("11001110") } },
    Format{ .operation = .iret, .fields = &.{ lit("11001111") } },

    Format{ .operation = .clc, .fields = &.{ lit("11111000") } },
    Format{ .operation = .cmc, .fields = &.{ lit("11110101") } },
    Format{ .operation = .stc, .fields = &.{ lit("11111001") } },
    Format{ .operation = .cld, .fields = &.{ lit("11111100") } },
    Format{ .operation = .std, .fields = &.{ lit("11111101") } },
    Format{ .operation = .cli, .fields = &.{ lit("11111010") } },
    Format{ .operation = .sti, .fields = &.{ lit("11111011") } },
    Format{ .operation = .hlt, .fields = &.{ lit("11110100") } },
    Format{ .operation = .wait, .fields = &.{ lit("10011011") } },
    Format{ .operation = .esc, .fields = &.{ lit("11011"), xxx, mod, yyy, rm } },
    Format{ .operation = .lock, .fields = &.{ lit("11110000") } },
    Format{ .operation = .segment, .fields = &.{ lit("001"), sr, lit("110") } },
};
