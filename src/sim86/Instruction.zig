const std = @import("std");
const assert = std.debug.assert;
const def = @import("defines.zig");

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

    pub fn format(self: OperandRegister, writer: *std.io.Writer) std.io.Writer.Error!void {
        assert(self.size != 0 and self.size != 3);
        if(self.size == 1) {
            try writer.print("{s}", .{ @tagName(self.rfid) });
        } else {
            try writer.print("{s}", .{ 
                switch (self.rfid) {
                    .al => "ax", .ah => "ax",
                    .cl => "cx", .ch => "cx",
                    .dl => "dx", .dh => "dx",
                    .bl => "bx", .bh => "bx",
                    .spl => "sp", .sph => "sp",
                    .bpl => "bp", .bph => "bp",
                    .sil => "si", .sih => "si",
                    .dil => "di", .dih => "di",
                    .csl => "cs", .csh => "cs",
                    .dsl => "ds", .dsh => "ds",
                    .esl => "es", .esh => "es",
                    .ssl => "ss", .ssh => "ss",
                    .ipl => "ip", .iph => "ip",
                    .fll => "flags", .flh => "flags",
                }
            });
        }
    }
};
pub const MemoryMode = enum {
    direct,
    bx_si, bx_di, bp_si, bp_di, 
    si, di, bp, bx,

    pub fn format(self: MemoryMode, writer: *std.io.Writer) std.io.Writer.Error!void {
        try writer.print("{s}", .{ 
            switch (self) {
                .direct => "",
                .bx_si => "bx+si", .bx_di => "bx+di",
                .bp_si => "bp+si", .bp_di => "bp+di",
                .si => "si", .di => "di", .bp => "bp", .bx => "bx",
            } 
        });
    }
};
pub const OperandMemory = struct {
    // Note: size should always be 2.
    segment: OperandRegister,
    mode: MemoryMode,
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
    if (self.operation == .segment or self.operation == .rep or self.operation == .lock) {
        return;
    }

    try writer.print("{s}", .{ if (self.flags.lock) "lock " else "" });
    try writer.print("{s}", .{ if (self.flags.rep) "rep " else "" });
    try writer.print("{s}", .{ @tagName(self.operation) });
    try writer.print("{s} ", .{ 
        if (self.flags.rep and self.flags.wide) "w"
        else if (self.flags.rep and !self.flags.wide) "b"
        else ""
    });

    // nasm expects xchg operands to be in different order.
    const operands: [2]Operand = .{
        if (self.flags.lock and self.operation == .xchg) self.operands[1] else self.operands[0],
        if (self.flags.lock and self.operation == .xchg) self.operands[0] else self.operands[1],
    };

    for(operands, 0..) |operand, idx| {
        switch(operand) {
            .none => {},
            .register => |register| {
                try writer.print("{f}", .{ register });
            },
            .memory => |memory| {
                if(operands[0] != .register) {
                    try writer.print("{s} ", .{ if(self.flags.wide) "word" else "byte" });
                }
                if(self.flags.segment) {
                    try writer.print("{f}", .{ memory.segment });
                }

                try writer.print("[{f}", .{ memory.mode });
                if(memory.displacement != 0) {
                    try writer.print("{d}", .{ memory.displacement });
                }
                try writer.print("]", .{});
            },
            .immediate => |immediate| {
                try writer.print("{d}", .{ immediate });
            },
            .relative_immediate => |rel_immediate| {
                try writer.print("${d}", .{ rel_immediate });
            },
        }

        if(idx == 0 and operands[1] != .none) {
            try writer.print(", ", .{});
        }
    }

    try writer.print("\n", .{ });
}
