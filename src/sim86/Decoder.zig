const std = @import("std");
const Instruction = @import("Instruction.zig");
const format = @import("format_table.zig");

const Self = @This();

ctx: Context = .{},

pub const Context = struct {
    default_segment: Instruction.RegisterFileId = .dsl,
    flags: Instruction.Flags = .{},
};

pub fn decode(self: *Self, memory: []u8) struct{ Instruction, []u8} {
    _ = self;
    // mov cx, bx
    const result: Instruction = .{  
        .address = 0, 
        .size_byte = 0, 
        .operation =  .mov,
        .operands = .{ 
            .{ .register = Instruction.OperandRegister{ .rfid = .cl, .size = 2 } },
            .{ .register = Instruction.OperandRegister{ .rfid = .bl, .size = 2 } },
        }, 
        .flags = .{
            .wide = true,
        },  
    };
    return .{ result, memory };
}
