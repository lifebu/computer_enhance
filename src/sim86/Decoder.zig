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

fn parse(T: type, memory: []u8, mem_idx: *u8, exists: bool, is_wide: bool, sign_extended: bool) ?T {
    const int_info: std.builtin.Type.Int = @typeInfo(T).int;
    _ = sign_extended; // TODO: What is this? Don't know if we need this? Casey uses it to cast u8 value to i8 (i think)

    return if (exists) {
        if (is_wide) {
            const word_type = @Type(std.builtin.Type{ .int = .{ .signedness = .unsigned, .bits = int_info.bits } });
            // TODO: This looks like a good case for the segmented access and not the sliding window view I used so far.
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
        0 => .{ .register = Instruction.OperandRegister{ .rfid = .al, .size = size } },
        1 => .{ .register = Instruction.OperandRegister{ .rfid = .cl, .size = size } },
        2 => .{ .register = Instruction.OperandRegister{ .rfid = .dl, .size = size } },
        3 => .{ .register = Instruction.OperandRegister{ .rfid = .bl, .size = size } },
        4 => .{ .register = Instruction.OperandRegister{ .rfid = if(is_wide) .spl else .ah, .size = size } },
        5 => .{ .register = Instruction.OperandRegister{ .rfid = if(is_wide) .bpl else .ch, .size = size } },
        6 => .{ .register = Instruction.OperandRegister{ .rfid = if(is_wide) .sil else .dh, .size = size } },
        7 => .{ .register = Instruction.OperandRegister{ .rfid = if(is_wide) .dil else .bh, .size = size } },
    };
}

const FieldResult = struct {
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
    
    fn fromUsage(self: *FieldResult, usage: format.FieldUsage, value: u8) void {
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
    var field_result: FieldResult = .{};
    var mem_idx: u8 = 0;
    var bits_to_read: u8 = 0;
    // TODO: If we make this "bits_removed", we might be able to make this u3 and save the cast below?
    var bits_pending: u8 = 0;

    const is_matching: bool = for(fmt.fields) |field| {
        var read: ?u8 = if(field.value) |val| val else null;
        if(field.bit_count != 0) {
            if(bits_pending == 0) {
                bits_pending = 8;
                bits_to_read = memory[mem_idx];
                mem_idx += 1;
            }

            assert(field.bit_count <= bits_pending); // bits straddling byte boundaries not allowed.
            bits_pending -= field.bit_count;
            const shift: u3 = @intCast(bits_pending); // cast is save: we remove field.bit_count and it is not zero => bits_pending < 8
            // TODO: bit_count can be 8, so this code no longer can compiles without this hack :/
            const mask = if(field.bit_count > 7) 0xff else ~(@as(u8, 0xff) << @as(u3, @intCast(field.bit_count)));
            read = (bits_to_read >> shift) & mask;
        }

        if(field.usage == .literal and read != field.value) {
            break false; // format does not match to memory.
        } else if(read != null) {
            FieldResult.fromUsage(&field_result, field.usage, read.?);
        }

    } else true;

    if(!is_matching) {
        return null;
    }

    const mod = field_result.mod orelse 0;
    const rm = field_result.rm orelse 0;

    const has_direct_addr: bool = (mod == 0b00) and (rm == 0b110);
    const has_disp: bool = field_result.has_disp or (mod == 0b10) or (mod == 0b01) or has_direct_addr;
    const has_wide_disp: bool = field_result.wide_disp or (mod == 0b10) or has_direct_addr;
    const has_data: bool = field_result.has_data;
    const has_wide_data: bool = (field_result.wide_for_data) and !field_result.sign and field_result.wide;

    field_result.disp = parse(i16, memory, &mem_idx, has_disp, has_wide_disp, !has_wide_disp);
    field_result.data = parse(u16, memory, &mem_idx, has_data, has_wide_data, field_result.sign);

    var result_flags = self.ctx.flags;
    result_flags.wide |= field_result.wide;

    // TODO: is disp always signed 16 bits?
    const disp: i16 = @bitCast(field_result.disp orelse 0);
    // const reg_operand_idx: u1 = if(reg_dest) 0 else 1;
    // const mod_operand_idx: u1 = if(reg_dest) 1 else 0;
    var reg_operand: Instruction.Operand = .none;
    var mod_operand: Instruction.Operand = .none;

    if(field_result.segment_reg) |segment_offset| {
        // TODO: How to do that better? I like Casey solution more, way easier.
        const rfid_int: u5 = @intFromEnum(Instruction.RegisterFileId.esl) + (2 * @as(u4, segment_offset));
        reg_operand = .{ .register = .{ .rfid = @enumFromInt(rfid_int), .size = 2 } };
    }

    if(field_result.reg) |reg_value| {
        reg_operand = getRegOperand(reg_value, field_result.wide);
    }

    if(field_result.mod) |mod_value| {
        if(mod_value == 0b11) {
            const mod_wide: bool = field_result.wide or field_result.wide_rm;
            mod_operand = getRegOperand(rm, mod_wide);
        } else {
            const is_direct_addr: bool = (mod == 0b00) and (rm == 0b110);
            // TODO: This 1 + RM looks pretty uggly
            const mode: Instruction.MemoryMode = if(is_direct_addr) Instruction.MemoryMode.direct else @enumFromInt(1 + @as(u5, rm));
            mod_operand = .{ .memory = .{
                .displacement = disp,
                .mode = mode,
                .segment = .{ .size = 2, .rfid = self.ctx.default_segment },
            } };
        }
    }

    var result: Instruction = .{
        .operation = fmt.operation,
        .flags = result_flags,
        .address = 0, // TODO: How to do that? Instead of subslicing input memory I would need to have memory and an incoming memory_idx.
        .size_byte = @intCast(mem_idx),
        .operands = .{ 
            if(field_result.reg_dest) reg_operand else mod_operand,
            if(field_result.reg_dest) mod_operand else reg_operand,
        }, 
    };

    // Some opcodes need immediates as operands => use the operand that has not bee in used so far.
    const unused_operand: *Instruction.Operand = if(result.operands[0] == .none) &result.operands[0] else &result.operands[1];
    if(field_result.jr_disp) {
        unused_operand.* = .{ .relative_immediate = disp + result.size_byte };
    }
    if(field_result.has_data) {
        unused_operand.* = .{ .immediate = field_result.data orelse 0 };
    }
    if(field_result.v) |v_value| {
        if(v_value) {
            unused_operand.* = .{ .register = .{
                .rfid = .cl,
                .size = 1,
            } };
        } else {
            // TODO: Casey had a "immediate s32"?
            unused_operand.* = .{ .immediate = 1 };
        }
    }

    return result;
}
