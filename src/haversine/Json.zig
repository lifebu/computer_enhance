const std = @import("std");
const assert = std.debug.assert;

const Self = @This();

label: ?[]const u8 = null,
value: ?[]const u8 = null,

first_child: ?*Self = null,
next_sibling: ?*Self = null,

pub fn init(alloc: std.mem.Allocator, buff: []const u8) !*Self {
    const result: *Self = try parse(alloc, buff);
    return result;
}

pub fn deinit(self: *const Self, alloc: std.mem.Allocator) void {
    assert(self.label != null); // Only allowed to deallocate the root json object.
    assert(std.mem.eql(u8, self.label.?, "root")); // Only allowed to deallocate the root json object.
    deinitInner(self, alloc);
    alloc.destroy(self);
} 
fn deinitInner(self: *const Self, alloc: std.mem.Allocator) void {
    var curr_child: ?*Self = self.first_child;
    while(curr_child) |child_elem| : (curr_child = curr_child.?.next_sibling) {
        child_elem.deinitInner(alloc);
        alloc.destroy(child_elem);
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

pub fn format(self: *const Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try formatInner(self, writer, 0);
}
fn formatInner(self: *const Self, writer: *std.Io.Writer, depth: usize) std.Io.Writer.Error!void {
    assert(depth < std.math.maxInt(u8)); // Deeper than 255 recursions?

    try writer.print("{*}:", .{ self });
    for(0..depth) |_| {
        try writer.print("--", .{});
    }
    try writer.print("{s}: {s}\n", .{ self.label orelse "", self.value orelse "" });

    var curr_child: ?*Self = self.first_child;
    while(curr_child) |child_elem| : (curr_child = curr_child.?.next_sibling) {
        try formatInner(child_elem, writer, depth + 1);
    }
}

pub const JSONError = error {
    TokenUnknown,
    TokenUnexpected,
    BufferExceeded,
    OutOfMemory,
};
const TokenType = enum {
    brace_open,
    brace_close,
    bracket_open,
    bracket_close,
    string,
    number,
    comma,
    colon,
    finished,
};
const Token = struct {
    type: TokenType,
    value: []const u8,

    pub fn format(self: *const Token, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("type: {t}, value: {s}", .{ self.type, self.value });
    }
};
const Parser = struct {
    buff: []const u8,
    idx: usize,

    fn isWhitespace(char: u8) bool {
        return char == ' ' or char == '\n' or char == '\t';
    }
    pub fn getNextToken(self: *Parser) !Token {
        if (self.idx >= self.buff.len - 1) {
            return .{ .type = .finished, .value = "" };
        }

        while (self.idx < self.buff.len and isWhitespace(self.buff[self.idx])): (self.idx += 1) {}
        const result: Token = switch (self.buff[self.idx]) {
            '{' => .{ .type = .brace_open, .value = self.buff[self.idx..][0..1] },
            '}' => .{ .type = .brace_close, .value = self.buff[self.idx..][0..1] },
            '[' => .{ .type = .bracket_open, .value = self.buff[self.idx..][0..1] },
            ']' => .{ .type = .bracket_close, .value = self.buff[self.idx..][0..1] },
            ',' => .{ .type = .comma, .value = self.buff[self.idx..][0..1] },
            ':' => .{ .type = .colon, .value = self.buff[self.idx..][0..1] },
            '"' => blk: {
                var next_idx: usize = self.idx + 1;
                while(next_idx < self.buff.len) : (next_idx += 1) {
                    if(self.buff[next_idx] == '"') {
                        break;
                    }
                } else return JSONError.BufferExceeded;

                const start_idx: usize = self.idx + 1; // Don't include the quote
                const value: []const u8 = self.buff[start_idx..next_idx];
                self.idx = next_idx;
                break: blk .{ .type = .string, .value = value };
            },
            '-', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' => blk: {
                var next_idx: usize = self.idx + 1;
                while(next_idx < self.buff.len) : (next_idx += 1) {
                    if(self.buff[next_idx] == ',' or self.buff[next_idx] == '\n') {
                        break;
                    }
                } else return JSONError.BufferExceeded;

                const value: []const u8 = self.buff[self.idx..next_idx];
                self.idx = next_idx - 1; // Include the ',' for the next token
                break: blk .{ .type = .number, .value = value };
            },
            else => |val| {
                std.log.err("Unknown Token: {c}", .{ val });
                return JSONError.TokenUnknown;
            }
        };

        self.idx += 1;
        //std.debug.print("Token: {f}\n", .{ result });
        return result;
    }
    pub fn parseList(parser: *Parser, alloc: std.mem.Allocator, start_token: Token, end_token_type: TokenType, has_labels: bool) JSONError!?*Self {
        std.debug.print("parseList: start_token: {f}, end_token_type: {t}, has_labels: {}\n", .{ start_token, end_token_type, has_labels });
        var first: ?*Self = null;
        var last: ?*Self = null;

        var token: Token = try parser.getNextToken();
        while(token.type != .finished) : (token = try parser.getNextToken()) {
            var label: ?[]const u8 = null;
            if (has_labels) {
                switch (token.type) {
                    .string => {
                        label = token.value;
                        token = try parser.getNextToken();
                        assert(token.type == .colon);
                        token = try parser.getNextToken();
                    },
                    else => |val| {
                        if (val != end_token_type) {
                            std.log.err("Failed to parse label. Got token: {t}", .{ val });
                            return JSONError.TokenUnexpected;
                        }
                    },
                }
            }

            const child: ?*Self = try parser.parseElement(alloc, label, token);
            if (child) |child_val| {
                if (first == null) first = child_val;
                if (last) |last_val| {
                    last_val.next_sibling = child_val; 
                }
                last = child_val;
            } else if (token.type == end_token_type) {
                break;
            } else {
                std.log.err("Expected end token. Got token: {t}", .{ token.type });
                return JSONError.TokenUnexpected;
            }

            const end_token: Token = try parser.getNextToken();
            if (end_token.type == end_token_type) {
                break;
            } else if (end_token.type != .comma) {
                std.log.err("Expected end token. Got token: {t}", .{ end_token.type });
                return JSONError.TokenUnexpected;
            }
        }

        return first;
    }

    pub fn parseElement(parser: *Parser, alloc: std.mem.Allocator, label: ?[]const u8, token: Token) JSONError!?*Self {
        std.debug.print("parseElement: label: {s}, token: {f}\n", .{ if(label) |label_val| label_val else "", token });
        var child: ?*Self = null;
        switch (token.type) {
            .brace_open => {
                child = try parser.parseList(alloc, token, .brace_close, true);
            },
            .bracket_open => {
                child = try parser.parseList(alloc, token, .bracket_close, false);
            },
            .string, .number => {},
            .finished => return null,
            else => |val| {
                std.log.err("Unexpected Token: {t}", .{ val });
                return JSONError.TokenUnexpected;
            }
        }

        const result: *Self = try alloc.create(Self);
        result.* = Self{ .label = label,  .value = token.value, .first_child = child, .next_sibling = null };
        return result;
    }
};

const print_tokens: bool = false;
fn parse(alloc: std.mem.Allocator, buff: []const u8) !*Self {
    if (print_tokens) {
        var parser: Parser = .{ .buff = buff, .idx = 0 };

        while (parser.getNextToken()) |token| {
            if (token.type == .finished) {
                break;
            }
        } else |err| return err;
        return .{};
    } else {
        var parser: Parser = .{ .buff = buff, .idx = 0 };
        const first_token: Token = try parser.getNextToken();
        const root: ?* Self = try parser.parseElement(alloc, "root", first_token);
        assert(root != null);
        return root.?;
    }

}
