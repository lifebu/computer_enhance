const std = @import("std");

// TODO: Conversion from reg u3 to RFID?
const RegField = enum(u3) {
    al, cl, dl, bl,
    ah, ch, dh, bh,
};
const RegFieldWide = enum(u3) {
    ax, cx, dx, bx,
    sp, bp, si, di,
};

const Opcode = enum(u6) {
    mov_register = 0b100010,
    _,

    pub fn format(self: @This(), writer: *std.io.Writer) std.io.Writer.Error!void {
        try writer.print("{s}", .{ 
            switch(self) {
                .mov_register => "mov",
                _ => "",
            } 
        });
    }
};

const Instruction = packed struct(u16) {
    wide: bool,         // 1 == 16-bit, 0 == 8-bit 
    dest: enum(u1) {    // destination
        rm_is_dest,
        reg_is_dest,
    },
    opcode: Opcode,     // opcode
    rm: u3,             // register-name OR memory
    reg: u3,            // register-name
    mod: enum(u2) {     // register or memory operation
        memory,
        memory_8bit_displacement,
        memory_16bit_displacement,
        register,
    },

    pub fn format(self: @This(), writer: *std.io.Writer) std.io.Writer.Error!void {
        const dest: u3, const src: u3 = switch (self.dest) {
            .rm_is_dest => .{ self.rm, self.reg },
            .reg_is_dest => .{ self.reg, self.rm },
        };
        const dest_tag = if(self.wide) @tagName(@as(RegFieldWide, @enumFromInt(dest))) 
            else @tagName(@as(RegField, @enumFromInt(dest)));
        const src_tag = if(self.wide) @tagName(@as(RegFieldWide, @enumFromInt(src))) 
            else @tagName(@as(RegField, @enumFromInt(src)));

        try writer.print("{f} {s}, {s}", .{ self.opcode, dest_tag, src_tag });
    }
};

const RegisterFile = packed union {
    r16: packed struct {
        ax: u16,
        cx: u16,
        dx: u16,
        bx: u16,
        sp: u16, // stack pointer
        bp: u16, // base pointer
        si: u16, // source index
        di: u16, // dest index
    },
    r8: packed struct {
        al: u8, ah: u8,
        cl: u8, ch: u8,
        dl: u8, dh: u8,
        bl: u8, bh: u8,
        spl: u8, sph: u8,
        bpl: u8, bph: u8,
        sil: u8, sih: u8,
        dil: u8, dih: u8,
    },
};

pub fn writeMnemonic(alloc: std.mem.Allocator, assembly: []const u8) ![]u8 {
    var array_list = try std.ArrayList(u8).initCapacity(alloc, 100);
    defer array_list.deinit(alloc);

    // TODO: Instructions can be different length.
    const byte_code: []align(1) const Instruction = std.mem.bytesAsSlice(Instruction, assembly);
    try array_list.print(alloc, "bits 16\n", .{});
    for (byte_code) |inst| {
        try array_list.print(alloc, "{f}\n", .{ inst });
    }

    return array_list.toOwnedSlice(alloc);
}
