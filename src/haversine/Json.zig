const std = @import("std");
const assert = std.debug.assert;

const Self = @This();

// TODO: labels are currently slices into the parse buffer => Their lifetimes are linked.
label: ?[]const u8 = null,
value: ?[]const u8 = null,

parent: ?*Self,
first_child: ?*Self = null,
next_sibling: ?*Self = null,

pub const Error = error {
    UnknownToken,
};

pub fn init(alloc: std.mem.Allocator, buff: []const u8) !Self {
    return try parse(alloc, buff);
}

pub fn deinit(self: *const Self, alloc: std.mem.Allocator) void {
    assert(self.parent == null); // Only allowed to deallocate the root json object.
    deinitInner(self, alloc);
} 
fn deinitInner(self: *const Self, alloc: std.mem.Allocator) void {
    var curr_child: ?*Self = self.first_child;
    while(curr_child) |child_elem| : (curr_child = curr_child.?.next_sibling) {
        child_elem.deinitInner(alloc);
        alloc.destroy(child_elem);
    }

    var curr_sibling: ?*Self = self.next_sibling;
    while(curr_sibling) |sibling| : (curr_sibling = curr_sibling.?.next_sibling) {
        sibling.deinitInner(alloc);
        alloc.destroy(sibling);
    }
}

pub fn getChild(self: Self, name: []const u8) ?*Self {
    var curr_child: ?*Self = self.first_child;
    while(curr_child) |child_elem| : (curr_child = curr_child.?.next_sibling) {
        if(child_elem.label != null and std.mem.eql(u8, child_elem.label.?, name)) {
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

pub fn format(self: *const Self, writer: *std.io.Writer) std.io.Writer.Error!void {
    try formatInner(self, writer, 0);
}
fn formatInner(self: *const Self, writer: *std.io.Writer, depth: usize) std.io.Writer.Error!void {
    assert(depth < std.math.maxInt(u8)); // Deeper than 255 recursions?
    
    try writer.print("{*}:", .{ self });
    for(0..depth) |_| {
        try writer.print("--", .{});
    }
    try writer.print("{s}{s}\n", .{ self.label orelse "", self.value orelse "" });

    var curr_child: ?*Self = self.first_child;
    while(curr_child) |child_elem| : (curr_child = curr_child.?.next_sibling) {
        try writer.print("child: {any}->{any}\n", .{ depth, depth + 1 });
        try formatInner(child_elem, writer, depth + 1);
    }

    var curr_sibling: ?*Self = self.next_sibling;
    while(curr_sibling) |sibling| : (curr_sibling = curr_sibling.?.next_sibling) {
        try writer.print("sibling: {any}->{any}\n", .{ depth, depth });
        try formatInner(sibling, writer, depth);
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
    var root: Self = .{ .parent = null, .label = "root" };
    var curr_parent: ?*Self = null;
    var curr_child: ?*Self = &root;

    var idx: usize = 0;
    while(idx < buff.len) {
        const char: u8 = buff[idx];
        switch(char) {
            '{', '[' => { // open a new child
                const new_child: *Self = try alloc.create(Self);
                new_child.* = .{ .parent = curr_child };

                curr_parent = curr_child;
                curr_parent.?.first_child = new_child;
                curr_child = new_child;
                std.debug.print("{f}\n", .{ root });
            },
            '"' => { // start label
                assert(curr_child != null);
                var next_idx: usize = idx + 1;
                while(next_idx < buff.len) : (next_idx += 1) {
                    if(buff[next_idx] == '"') {
                        break;
                    }
                }

                const label: []const u8 = buff[(idx + 1)..next_idx];
                curr_child.?.label = label;
                idx = next_idx;
            },
            ':' => { // either literal or substructure
                var next_idx: usize = idx + 1;
                var found_literal: bool = false;
                while(next_idx < buff.len) : (next_idx += 1) {
                    const next_char: u8 = buff[next_idx];
                    if (next_char == '[' or next_char == '{') {
                        break;
                    } else if (next_char == ',' or next_char == '\n') {
                        found_literal = true;
                        next_idx -= 1;
                        break;
                    }
                }

                if(found_literal) {
                    assert(curr_child != null);
                    // TODO: Remove whitespace from this?
                    curr_child.?.value = buff[(idx + 1)..next_idx];
                    idx = next_idx;
                    std.debug.print("{f}\n", .{ root });
                }
            },
            ',' => { // create a new sibling
                assert(curr_parent != null);
                const new_sibling: *Self = try alloc.create(Self);
                new_sibling.* = .{ .parent = curr_parent };
                curr_child = new_sibling;

                var last_child = curr_parent.?.first_child;
                assert(last_child != null);
                while(last_child != null and last_child.?.next_sibling != null) : (last_child = last_child.?.next_sibling) {}
                last_child.?.next_sibling = new_sibling;
                std.debug.print("{f}\n", .{ root });
            },
            '}', ']' => { // close current child
                assert(curr_parent != null);
                curr_child = curr_parent;
                curr_parent = curr_parent.?.parent;
                std.debug.print("{f}\n", .{ root });
            },
            '\n', '\t', ' ', => {},
            else => return Error.UnknownToken,
        }

        idx += 1;
    }

    return root;
}
