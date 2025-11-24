const std = @import("std");
const def = @import("defines.zig");

// 1st: instruction table or function (getOpcde() + getFields()) that gives me definition for an instruction.
// table can also encode implicity knowledge about an instruction. 
// (ALU versions of instructions also define that they use the alu register). 
// All the fields that are technically not in the bytes but we define when we define the table.
// Pseudofields (they have a value)! otherwise get it from the instruction stream.
// Implicitly Wide. 
// Instruction Table is a [256]Array

const Self = @This();

address: u32,
size_byte: u3,

operation: def.Operation,
operands: [2]Operand,
flags: Flags,

pub const RegisterFileId = enum(u5) {
    al, ah, // ax (u16), al, ah: (u8)
    cl, ch, // cx (u16), cl, ch: (u8)
    dl, dh, // dx (u16), dl, dh: (u8)
    bl, bh, // bx (u16), bl, bh: (u8)
    spl, sph, // stack pointer: u16,
    bpl, bph, // base pointer: u16,
    sil, sih, // source index: u16,
    dil, dih, // dest index: u16,
    csl, csh, // code segment: u16,
    dsl, dsh, // data segment: u16,
    esl, esh, // extra segment: u16,
    ssl, ssh, // stack segment: u16,
    ipl, iph, // instruction pointer: u16,
    fll, flh, // flags register: u16,
};
pub const OperandRegister = struct {
    rfid: RegisterFileId,
    size: u2,
};
pub const OperandMemory = struct {
    rfid: RegisterFileId,
    mode: enum(u4) {
        direct,
        bx_si, bx_di, bp_si, bp_di, 
        si, di, bp, bx,
    },
    displacement: u16,
};
pub const Operand = union(enum) {
    none: void,
    register: OperandRegister,
    memory: OperandMemory,
    immediate: u16,
    relative_immediate: i16,
};
pub const Flags = packed struct {
    lock: bool = false,
    rep: bool = false,
    segment: bool = false,
    wide: bool = false,
};

pub fn format(self: Self, writer: *std.io.Writer) std.io.Writer.Error!void {
    // TODO: Figure out source and dest.
    try writer.print("{s} {s}, {s}", .{ @tagName(self.operation), @tagName(self.operands[0].register.rfid), @tagName(self.operands[1].register.rfid) });
}
