const std = @import("std");
const assert = std.debug.assert;

const Instruction = @import("Instruction.zig");
const format = @import("format_table.zig");

const Self = @This();

ctx: Context = .{},

pub const Context = struct {
    default_segment: Instruction.RegisterFileId = .dsl,
    flags: Instruction.Flags = .{},
};

pub fn disAsm(self: *Self, alloc: std.mem.Allocator, memory: []u8) ![]u8 {
    var result = try std.ArrayList(u8).initCapacity(alloc, 100);
    defer result.deinit(alloc);

    try result.print(alloc, "bits 16\n", .{});

    var instr_idx: usize = 0;
    var view: []u8 = memory;
    while(view.len != 0) {
        const instr: Instruction = self.decode(view) orelse {
            std.debug.print("No fitting instruction found at idx: {}\n", .{ instr_idx });
            unreachable;
        };
        assert(instr.size_byte > 0); // decoded zero length instruction?
        try result.print(alloc, "{f}", .{ instr });
        view = view[instr.size_byte..];
        instr_idx += 1;
    }

    return result.toOwnedSlice(alloc);
}

pub fn decode(self: *Self, memory: []u8) ?Instruction {
    for(format.Table) |elem| {
        if(self.tryDecode(elem, memory)) |result| {
            self.updateContext(result);
            return result; 
        }
    }
    return null;
}

// TODO: out parameter for the index: A good case for the segmented access and not the sliding window view I used so far (see disAsm()).
fn parse(T: type, memory: []u8, mem_idx: *u8, exists: bool, is_wide: bool, sign_extended: bool) ?T {
    const int_info: std.builtin.Type.Int = @typeInfo(T).int;
    _ = sign_extended; // TODO: What is this? Don't know if we need this? Casey uses it to cast u8 value to i8 (i think)

    return if (exists) {
        if (is_wide) {
            const word_type = @Type(std.builtin.Type{ .int = .{ .signedness = .unsigned, .bits = int_info.bits } });
            const unsigend: word_type = memory[mem_idx.*] | (@as(u16, memory[mem_idx.* + 1]) << 8);
            const result: T = @bitCast(unsigend);
            mem_idx.* += 2;
            return result;
        } else {
            const byte_type = @Type(std.builtin.Type{ .int = .{ .signedness = int_info.signedness, .bits = 8 } });
            const unsigned: u8 = memory[mem_idx.*];
            const result: byte_type = @bitCast(unsigned);
            mem_idx.* += 1;
            return result;
        }
    } else null;
}

fn getRegOperand(value: u3, is_wide: bool) Instruction.Operand {
    const size: u2 = if(is_wide) 2 else 1;
    return switch(value) {
        0 => .{ .register = .{ .rfid = .al, .size = size } },
        1 => .{ .register = .{ .rfid = .cl, .size = size } },
        2 => .{ .register = .{ .rfid = .dl, .size = size } },
        3 => .{ .register = .{ .rfid = .bl, .size = size } },
        4 => .{ .register = .{ .rfid = if(is_wide) .spl else .ah, .size = size } },
        5 => .{ .register = .{ .rfid = if(is_wide) .bpl else .ch, .size = size } },
        6 => .{ .register = .{ .rfid = if(is_wide) .sil else .dh, .size = size } },
        7 => .{ .register = .{ .rfid = if(is_wide) .dil else .bh, .size = size } },
    };
}

const Fields = struct {
    literal: ?u8 = null,
    mod: ?u2 = null,
    reg: ?u3 = null,
    rm: ?u3 = null,
    segment_reg: ?u2 = null,
    disp: ?i16 = null,
    data: ?u16 = null,
    has_disp: bool = false,
    wide_disp: bool = false,
    has_data: bool = false,
    wide_for_data: bool = false,
    wide_rm: bool = false,
    jr_disp: bool = false,
    reg_dest: bool = false,
    sign: bool = false,
    wide: bool = false,
    v: ?bool = null,
    z: ?bool = null,
    
    fn readAs(self: *Fields, value: u8, usage: format.FieldUsage) void {
        switch (usage) {
            .literal => self.literal = value,
            .rm => self.rm = @intCast(value),
            .mod => self.mod = @intCast(value),
            .reg => self.reg = @intCast(value),
            .segment_reg => self.segment_reg = @intCast(value),
            .has_disp => self.has_disp = value != 0,
            .wide_disp => self.wide_disp = value != 0,
            .has_data => self.has_data = value != 0,
            .wide_for_data => self.wide_for_data = value != 0,
            .wide_rm => self.wide_rm = value != 0,
            .jr_disp => self.jr_disp = value != 0,
            .reg_dest => self.reg_dest = value != 0,
            .sign => self.sign = value != 0,
            .wide => self.wide = value != 0,
            .v => self.v = value != 0,
            .z => self.z = value == 0,
            .data => {},
            .disp => {},
        }
    }
};

fn updateContext(self: *Self, result: Instruction) void {
    switch (result.operation) {
        .lock => {
            self.ctx.flags.lock = true;
        },
        .rep => {
            self.ctx.flags.rep = true;
        },
        .segment => {
            self.ctx.flags.segment = true;
            self.ctx.default_segment = result.operands[1].register.rfid;
        },
        else => {
            self.ctx = .{};
        },
    }
}

fn tryDecode(self: *Self, fmt: format.Format, memory: []u8) ?Instruction {
    var fields: Fields = .{};
    var mem_idx: u8 = 0;

    var read_byte: u8 = 0;
    var bits_pending: u4 = 0;
    for(fmt.fields) |field| {
        var read: ?u8 = field.value orelse null;
        if(field.bit_count != 0) {
            if(bits_pending == 0) {
                bits_pending = 8;
                read_byte = memory[mem_idx];
                mem_idx += 1;
            }

            assert(field.bit_count <= bits_pending); // bits straddling byte boundaries not allowed.
            bits_pending -= field.bit_count;
            const shift: u3 = @intCast(bits_pending);
            const mask = if (field.bit_count > 7) 0xff else (@as(u8, 1) << @intCast(field.bit_count)) - 1;
            read = (read_byte >> shift) & mask;
        }

        if(field.usage == .literal and read != field.value) {
            return null; // format does not match to memory.
        } else {
            assert(read != null);
            fields.readAs(read.?, field.usage);
        }
    }
    assert(bits_pending == 0); // No bits were unused

    const mod = fields.mod orelse 0;
    const rm = fields.rm orelse 0;

    // disp
    const has_direct_addr: bool = (mod == 0b00) and (rm == 0b110);
    const has_disp: bool = fields.has_disp or (mod == 0b10) or (mod == 0b01) or has_direct_addr;
    const has_wide_disp: bool = fields.wide_disp or (mod == 0b10) or has_direct_addr;
    fields.disp = parse(i16, memory, &mem_idx, has_disp, has_wide_disp, !has_wide_disp);
    const disp: i16 = fields.disp orelse 0;

    // data
    const has_data: bool = fields.has_data;
    const has_wide_data: bool = (fields.wide_for_data) and !fields.sign and fields.wide;
    fields.data = parse(u16, memory, &mem_idx, has_data, has_wide_data, fields.sign);

    // flags
    var result_flags = self.ctx.flags;
    result_flags.wide |= fields.wide;

    // operands
    var reg_operand: Instruction.Operand = .none;
    if(fields.segment_reg) |segment_offset| {
        const rfid_int: u5 = @intFromEnum(Instruction.RegisterFileId.esl) + (2 * @as(u4, segment_offset));
        reg_operand = .{ .register = .{ .rfid = @enumFromInt(rfid_int), .size = 2 } };
    } else if(fields.reg) |reg_value| {
        reg_operand = getRegOperand(reg_value, fields.wide);
    }

    var mod_operand: Instruction.Operand = .none;
    if(fields.mod) |mod_value| {
        if(mod_value == 0b11) {
            const mod_wide: bool = fields.wide or fields.wide_rm;
            mod_operand = getRegOperand(rm, mod_wide);
        } else {
            const mode_int: u5 = 1 + @as(u5, rm);
            mod_operand = .{ .memory = .{
                .displacement = disp,
                .mode = if(has_direct_addr) .direct else @enumFromInt(mode_int),
                .segment = .{ .size = 2, .rfid = self.ctx.default_segment },
            } };
        }
    }

    var first_operand = if(fields.reg_dest) reg_operand else mod_operand;
    var second_operand = if(fields.reg_dest) mod_operand else reg_operand;
    const size_byte: u3 = @intCast(mem_idx);

    // Some opcodes need immediates as operands => use the operand that has not been in use so far.
    const unused_operand: *Instruction.Operand = if(first_operand == .none) &first_operand else &second_operand;
    if(fields.jr_disp) {
        unused_operand.* = .{ .relative_immediate = disp + size_byte };
    } else if(fields.has_data) {
        unused_operand.* = .{ .immediate = fields.data orelse 0 };
    } else if(fields.v != null and fields.v.?) {
        unused_operand.* = .{ .register = .{ .rfid = .cl, .size = 1, } };
    } else if(fields.v != null and !fields.v.?) {
        // TODO: Casey had a "immediate s32"?
        unused_operand.* = .{ .immediate = 1 };
    }

    return Instruction {
        .operation = fmt.operation,
        .flags = result_flags,
        // TODO: How to do that? Instead of subslicing input memory I would need to have memory and an incoming memory_idx.
        .address = 0, 
        .size_byte = size_byte,
        .operands = .{ 
            first_operand,
            second_operand,
        }, 
    };
}
