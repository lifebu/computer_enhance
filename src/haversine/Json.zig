const std = @import("std");
const assert = std.debug.assert;

const Self = @This();

is_root: bool = false,
label: []const u8 = undefined,
value: ?[]const u8 = undefined,

first_child: ?*Self = null,
next_sibling: ?*Self = null,

pub const Error = error {
    UnknownToken,
};

pub fn init(alloc: std.mem.Allocator, buff: []const u8) !Self {
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

const ParentStack = struct {
    curr: *Self,
    prev: *Self,
};

fn parse(alloc: std.mem.Allocator, buff: []const u8) !Self {
    var root: Self = .{ .is_root = true };
    var curr_parent: *Self = &root;
    var curr_child: ?*Self = null;

    var idx: usize = 0;
    while(idx < buff.len) {
        const char: u8 = buff[idx];
        switch(char) {
            '{', '[' => { // open a new child
                // TODO: When to switch curr_parent?
                // Probably need a "stack" of parents.
                const new_child: *Self = try alloc.create(Self);
                if (curr_parent.first_child == null) {
                    curr_parent.first_child = new_child;
                    curr_child = new_child;
                } else {
                    curr_child.?.next_sibling = new_child;
                    curr_child = new_child;
                }
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
            ':' => {
                var next_idx: usize = idx + 1;
                var found_comma: bool = false;
                while(next_idx < buff.len) : (next_idx += 1) {
                    if (buff[next_idx] == '[') {
                        break;
                    } else if (buff[next_idx] == ',') {
                        found_comma = true;
                        break;
                    }
                }

                // TODO: We don't have , all the time (last element).
                if(found_comma) {
                    assert(curr_child != null);
                    // TODO: Remove whitespace from this?
                    curr_child.?.value = buff[(idx + 1)..next_idx];
                }
            },
            '}', ']' => { // close current child => go back to parent?

            },
            '\n', '\t', ' ', ',' => {},
            else => return Error.UnknownToken,
        }

        idx += 1;
    }

    return root;
}
