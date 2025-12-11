const std = @import("std");
const assert = std.debug.assert;

const Self = @This();

is_root: bool = false,
label: []const u8 = undefined,
value: ?[]const u8 = undefined,

first_child: ?*Self = null,
next_sibling: ?*Self = null,

// TODO:
// {} => Struct
    // "label" : ... 
// [] => Array

pub const Error = error {
    UnknownToken,
};

pub fn init(alloc: std.mem.Allocator, buff: []const u8) Error!Self {
    return try parse(alloc, buff);
}

pub fn deinit(self: *const Self, alloc: std.mem.Allocator) void {
    assert(self.is_root); // Only allowed to deallocate the root json object.
    
    var curr_child: ?*Self = self.first_child;
    while(curr_child) |child_elem| : (curr_child = curr_child.?.next_sibling) {
        child_elem.deinit(alloc);
        alloc.destroy(child_elem);
    }

    var curr_sibling: ?*Self = self.next_sibling;
    while(curr_sibling) |sibling| : (curr_sibling = curr_sibling.?.next_sibling) {
        sibling.deinit(alloc);
        alloc.destroy(sibling);
    }
} 

pub fn getChild(self: Self, name: []const u8) ?*Self {
    var curr_child: ?*Self = self.first_child;
    while(curr_child) |child_elem| : (curr_child = curr_child.?.next_sibling) {
        if(std.mem.eql(u8, child_elem.label, name)) {
            return curr_child;
        }
    }
    return null;
}

pub fn getElem(self: Self, name: []const u8, T: type) !T {
    const child: ?*Self = self.getChild(name);
    assert(child != null); // Child not found.
    assert(child.?.value != null); // Tried to access a json element that has no value.
    if (child.?.value.?.len == 0) {
        return 0;
    }
    
    const type_info: std.builtin.Type = @typeInfo(T);
    switch(type_info) {
        // TODO: Should I write the float parse myself as well?
        .float => return try std.fmt.parseFloat(T, child.?.value.?),
        else => return 0,
    }
}

const Token = enum {
    brace_open,
    brace_close,
    bracket_open,
    bracked_close,
    string,
    number,
    comma,
};

fn parse(alloc: std.mem.Allocator, buff: []const u8) !Self {
    var idx: usize = 0;
    while(idx < buff.len) {
        const char: u8 = buff[idx];
        switch(char) {
            //"{" => ,
            //else => return Error.UnknownToken,
            else => return .{ .is_root = true },
        }

        idx += 1;
    }
    _ = alloc;
    return .{

        .is_root = true,
    };
}
