const std = @import("std");
const Instruction = @import("Instruction.zig");
const format = @import("format_table.zig");

const Self = @This();

ctx: Context = .{},

pub const Context = struct {
    default_segment: Instruction.RegisterFileId = .dsl,
    flags: Instruction.Flags = .{},
};

pub fn disAsm(self: *Self, alloc: std.mem.Allocator, memory: []u8) ![]Instruction {
    var result = try std.ArrayList(Instruction).initCapacity(alloc, 100);
    defer result.deinit(alloc);
    
    var view: []u8 = memory;
    while(view.len != 0) {
        const instr: Instruction = self.decode(memory);
        try result.append(alloc, instr);
        view = view[instr.size_byte..];
    }

    return result.toOwnedSlice(alloc);
}

pub fn decode(self: *Self, memory: []u8) Instruction {
    _ = self;
    _ = memory;
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
    return result;
}
