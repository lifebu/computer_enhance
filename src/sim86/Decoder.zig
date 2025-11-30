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
    for(format.Table) |elem| {
        if(self.tryDecode(elem, memory)) |result| return result; 
    }

    // TODO: If we don't find an actual format this need to error out.

    // mov dx, bx
    const fallback: Instruction = .{  
        .address = 0, 
        .size_byte = 1, 
        .operation =  .mov,
        .operands = .{ 
            .{ .register = Instruction.OperandRegister{ .rfid = .dl, .size = 2 } },
            .{ .register = Instruction.OperandRegister{ .rfid = .bl, .size = 2 } },
        }, 
        .flags = .{
            .wide = true,
        },  
    };
    return fallback;
}

fn tryDecode(self: *Self, instr_format: format.Format, memory: []u8) ?Instruction {
    // const result: Instruction = .{};
    //
    // // TODO: Write that better.
    // switch (result.operation) {
    //     .lock => {
    //         self.ctx.flags.lock = true;
    //     },
    //     .rep => {
    //         self.ctx.flags.rep = true;
    //     },
    //     .segment => {
    //         self.ctx.flags.segment = true;
    //         self.ctx.default_segment = result.operands[1].register.rfid;
    //     },
    //     else => {
    //         self.ctx = .{};
    //     },
    // }

    _ = self;
    _ = memory;
    _ = instr_format;
    return null;
}
