const std = @import("std");
const assert = std.debug.assert;

const Self = @This();

is_root: bool = false,
label: []const u8 = undefined,
value: []const u8 = undefined,

first_child: ?*Self = null,
next_sibling: ?*Self = null,

pub fn init(alloc: std.mem.Allocator, buff: []const u8) Self {
    _ = alloc;
    _ = buff;
    return .{
        .is_root = true,
    };
}

pub fn deinit(self: *const Self) void {
    assert(self.is_root);
} 

pub fn lookupChild(self: Self, name: []const u8) *Self {
    _ = self;
    _ = name;
    return .{};
}

pub fn convert(self: Self, T: type) T {
    _ = self;
    return .{};
}
