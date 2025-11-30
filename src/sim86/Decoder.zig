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

    var view: []u8 = memory;
    while(view.len != 0) {
        const instr: Instruction = self.decode(memory);
        assert(instr.size_byte > 0); // decoded zero length instruction?
        try result.print(alloc, "{f}", .{ instr });
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
        .size_byte = 1, 
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
