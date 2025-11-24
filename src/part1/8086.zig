const std = @import("std");
const assert = std.debug.assert;

// TODO: New design:
// https://github.com/cmuratori/computer_enhance/blob/Part1_0_SlowDecode/perfaware/sim86/sim86.h 
// 1st: instruction table or function (getOpcde() + getFields()) that gives me definition for an instruction.
    // table can also encode implicity knowledge about an instruction. 
    // (ALU versions of instructions also define that they use the alu register). 
    // All the fields that are technically not in the bytes but we define when we define the table.
    // Pseudofields (they have a value)! otherwise get it from the instruction stream.
    // Implicitly Wide. 
    // Instruction Table is a [256]Array
// 2nd: decoder: Takes instruction table + slice of memory and returns instruction + new subslice.
// 3rd: printer: takes instruction and returns one line of text for that instruction.
// Decoder Context: once needed so that previous instructions can have effect on the next instruction.
// Do we have enough bytes left in slice for this instruction?
// use actual flags for knowing if an isntruction is wide or not.
// instead of "just reading asm", it loads a file that represents memory i can use.
    // have a memory struct with ther 1mbyte of memory of the 8086 (slice)?
    // 8086 memory can be accessed out of bounds (if not enough memory is available), by masking bits away we don't have. 


// Registers
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
        spl: u8, sph: u8, // invalid
        bpl: u8, bph: u8, // invalid
        sil: u8, sih: u8, // invalid
        dil: u8, dih: u8, // invalid
    },
};

// Prefix
const Opcode = enum(u6) {
    mov_rm,
    mov_rm_imm,
    mov_r_imm,
    mov_mem_acc,
    mov_acc_mem,
    _,

    pub fn format(self: @This(), writer: *std.io.Writer) std.io.Writer.Error!void {
        try writer.print("{s}", .{ 
            switch(self) {
                .mov_rm, .mov_rm_imm, .mov_r_imm, .mov_mem_acc, .mov_acc_mem => "mov",
                _ => "",
            } 
        });
    }
};
// TODO: Move the infix size from the opcode. The opcode defines everything else (infix, displacement, data).
pub fn parseOpcode(byte: u8) struct { Opcode, usize } {
    return switch(byte) {
        0b1000_1000...0b1000_1011 => .{ .mov_rm, 1 },
        0b1100_0110...0b1100_0111 => .{ .mov_rm_imm, 1 },
        0b1011_0000...0b1011_1111 => .{ .mov_r_imm, 0 },
        0b1010_0000...0b1010_0001 => .{ .mov_mem_acc, 0 },
        0b1010_0010...0b1010_0011 => .{ .mov_acc_mem, 0 },
        else => undefined,
    };
}

// Infix
// TODO: Conversion from reg u3 to RFID?
const RegField = enum(u3) {
    al, cl, dl, bl,
    ah, ch, dh, bh,
};
const RegFieldWide = enum(u3) {
    ax, cx, dx, bx,
    sp, bp, si, di,
};
// TODO: This enum should also include the direct effective addresses?
// TODO: Maybe encode the entire effective address expression?
const RegMemField = enum(u3) {
    bx_si, bx_di, bp_si, bp_di, 
    si, di, bp, bx,
};
const ModField = enum(u2) {
    memory,                     // [...] => No displacement or 2-byte displacement iff rm == 110.
    memory_8bit_displacement,   // [...+8] => 1 extra byte displacement.
    memory_16bit_displacement,  // [...+16] => 2 extra byte displacement.
    register,                   // bx
};
const Infix = packed struct(u8) {
    rm: u3,         // register-name OR memory
    reg: u3,        // register-name
    mod: ModField,  // register or memory operation
};


// TODO: Multiple Instructions and Suffixes
// first byte: prefix.
// Homework: listing_0039
    // Register and memory: 
        // - Check Mod field (for memory transfers).
        // - Instructions can now be longer depending on the mod field.
        // load: mov bx, [75], store: mov [75], bx => bx loads [75] and [76] (2 bytes)
        // effective address calculation: mov bx, [bp + 75]
        // - Check mod field: if 11 => register else it must be memory and check more.
    // Immediate-register-move: move ax, 12 
        // Here we have only one "base-byte".
    // Signed immediates: just always print the unsigned value.
// Challenge-Homework: listing_0040
    // mov immediate to memory: mov [BP+75], 12: Do we write 16-bits or 8-bits?
    // => mov [BP+75],byte12 or mov [BP+75],word12 (sets w flag!). 
    // => implement all moves in the manual but not segment register versions. 

// TODO: Instead of one table for the opcode and a table for the fields have a single table.
// TODO: Don't define the length in bits, but in bytes.
pub fn getOpcode(prefix: u8) Opcode {
    return switch(prefix) {
        0b1000_1000...0b1000_1011 => .mov_rm,
        0b1100_0110...0b1100_0111 => .mov_rm_imm,
        0b1011_0000...0b1011_1111 => .mov_r_imm,
        0b1010_0000...0b1010_0001 => .mov_mem_acc,
        0b1010_0010...0b1010_0011 => .mov_acc_mem,
        else => unreachable,
    };
}

const Fields = struct {
    // TODO: Maybe src and dest are tagged unions? for registers, memory calculations and immediates?
    // Then we don't need to switch later again.
    dest: u3,
    src: ?u3 = null,
    wide: bool,
    rm: ?u3 = null,     // register-name OR memory
    reg: ?u3 = null,    // register-name
    mod: ?ModField = null,
    displacement: ?u16 = null,
    data: ?u16 = null,
    len: u3,
};
pub fn getFields(opcode: Opcode, assembly: []const u8, idx: usize) Fields {
    const prefix: u8 = assembly[idx];
    return switch (opcode) {
        .mov_rm => blk: {
            const infix: Infix = @bitCast(assembly[idx + 1]);
            const reg_is_dest: bool = prefix & 0b0000_0010 != 0;
            break :blk Fields{
                .dest = if(reg_is_dest) infix.reg else infix.rm,
                .src = if(reg_is_dest) infix.rm else infix.reg,
                .wide = prefix & 0b0000_0001 != 0,
                .rm = infix.rm,
                .reg = infix.reg,
                .mod = infix.mod,
                .len = 2,
            };
        },
        .mov_r_imm => blk: {
            const wide: bool = prefix & 0b0000_1000 != 0;
            const data_size: u3 = if(wide) 2 else 1;
            const reg: u3 = @truncate(prefix & 0b0000_0111);
            // TODO: implement 16-bit immediate.
            // std.mem.bytesAsValue(u16, assembly[idx+1..][0..2]).*
            break :blk Fields{
                .dest = reg,
                .wide = wide,
                .reg = reg,
                .data = if(wide) 0 else assembly[idx + 1],
                .len = 1 + data_size,
            };
        },
        else => unreachable,
    };
}

// TODO: Maybe the output of the decoder should be an opcode + payload (tagged union).
pub fn writeMnemonic(alloc: std.mem.Allocator, assembly: []const u8) ![]u8 {
    var array_list = try std.ArrayList(u8).initCapacity(alloc, 100);
    defer array_list.deinit(alloc);

    try array_list.print(alloc, "bits 16\n", .{});

    var idx: usize = 0;
    while(idx < assembly.len) {
        const prefix: u8 = assembly[idx];
        const opcode: Opcode = getOpcode(prefix);
        const fields: Fields = getFields(opcode, assembly, idx);

        const opcode_supported: bool = opcode == .mov_rm or opcode == .mov_r_imm;
        const fields_supported: bool = fields.mod == null or fields.mod.? == .register;
        if(!opcode_supported or !fields_supported) {
            return array_list.toOwnedSlice(alloc);
        }

        try array_list.print(alloc, "{f} ", .{ opcode });

        const dest_tag = if(fields.wide) @tagName(@as(RegFieldWide, @enumFromInt(fields.dest))) 
            else @tagName(@as(RegField, @enumFromInt(fields.dest)));
        try array_list.print(alloc, "{s}, ", .{ dest_tag });

        switch (opcode) {
            .mov_rm => {
                const src_tag = if(fields.wide) @tagName(@as(RegFieldWide, @enumFromInt(fields.src.?))) 
                    else @tagName(@as(RegField, @enumFromInt(fields.src.?)));
                try array_list.print(alloc, "{s}", .{ src_tag });
            },
            .mov_r_imm => {
                try array_list.print(alloc, "{d}", .{ fields.data.? });
            },
            else => unreachable,
        }
        try array_list.print(alloc, "\n", .{});

        idx += fields.len;
    }

    return array_list.toOwnedSlice(alloc);
}
