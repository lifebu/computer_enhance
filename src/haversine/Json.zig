const std = @import("std");
const assert = std.debug.assert;

const metrics = @import("metrics.zig");

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// JSON

const Self = @This();

label: ?[]const u8 = null,
value: ?[]const u8 = null,
first_child: ?*Self = null,
next_sibling: ?*Self = null,

const max_depth = 10;
const max_width = 1_000;
const JSONError = error {
    // Parsing
    TokenUnknown,
    TokenUnexpected,
    BufferExceeded,
    OutOfMemory,
    // Querry
    ChildNotFound,
    HasNoValue,
};

pub fn format(self: *const Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try formatRecursive(self, writer, 0);
}
fn formatRecursive(self: *const Self, writer: *std.Io.Writer, depth: usize) std.Io.Writer.Error!void {
    assert(depth < max_depth);

    try writer.print("{*}", .{ self });
    for(0..depth) |_| try writer.print("-", .{});
    try writer.print("{s}: {s}\n", .{ self.label orelse "", self.value orelse "" });

    var curr_child: ?*Self = self.first_child;
    while(curr_child) |child_elem| : (curr_child = curr_child.?.next_sibling) {
        try formatRecursive(child_elem, writer, depth + 1);
    }
}

pub fn init(alloc: std.mem.Allocator, buff: []const u8) !*Self {
    var parser: Parser = .{ .buff = buff, .idx = 0 };
    const first_token: Token = try parser.getNextToken();
    const root_opt: ?* Self = try parser.parseElement(alloc, "root", first_token);
    const root: *Self = root_opt orelse @panic("JSON root could not be allocated");
    return root;
}

pub fn deinit(self: *const Self, alloc: std.mem.Allocator) void {
    metrics.pushScope("Json::Deinit"); defer metrics.popScope();
    assert(self.label != null); // Tried to free nothing?
    assert(std.mem.eql(u8, self.label.?, "root")); // Only allowed to deallocate the root json object.
    deinitRecursive(self, alloc, 0);
} 
fn deinitRecursive(self: ?*const Self, alloc: std.mem.Allocator, depth: usize) void {
    assert(depth < max_depth); // max recursion depth exceeded.
    var curr: ?*const Self = self;
    while (curr) |curr_element| {
        deinitRecursive(curr_element.first_child, alloc, depth + 1);
        curr = curr_element.next_sibling;
        alloc.destroy(curr_element);
    }
}

pub fn getChild(self: Self, name: []const u8) !*Self {
    assert(name.len != 0);
    var curr_child: ?*Self = self.first_child;
    return while(curr_child) |child_elem| : (curr_child = curr_child.?.next_sibling) {
        if(child_elem.label != null and std.mem.eql(u8, child_elem.label.?, name)) {
            return child_elem;
        }
    } else JSONError.ChildNotFound;
}

pub fn getElem(self: Self, name: []const u8, T: type) !T {
    assert(name.len != 0);
    const child: *Self = try self.getChild(name);
    const value: []const u8 = child.value orelse return JSONError.HasNoValue;
    
    const type_info: std.builtin.Type = @typeInfo(T);
    switch(type_info) {
        .float => return try std.fmt.parseFloat(T, value),
        else => return 0,
    }
}

pub fn printAllTokens(buff: []const u8) !void {
    var parser: Parser = .{ .buff = buff, .idx = 0 };
    while (parser.getNextToken()) |token| {
        std.debug.print("Token: {f}\n", .{ token });
        if (token.type == .finished) break;
    } else |err| return err;
    return .{};
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Parser

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
            else => |val| { std.log.err("Unknown Token: {c}", .{ val }); return JSONError.TokenUnknown; },
        };

        self.idx += 1;
        return result;
    }

    pub fn parseList(parser: *Parser, alloc: std.mem.Allocator, comptime end_token_type: TokenType, comptime has_labels: bool) JSONError!?*Self {
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
                        if (token.type != .colon) {
                            std.log.err("Parse label failed with token: {t}", .{ token.type }); return JSONError.TokenUnexpected;
                        }
                        token = try parser.getNextToken();
                    },
                    end_token_type => {},
                    else => { std.log.err("Parse label failed with token: {t}", .{ token.type }); return JSONError.TokenUnexpected; },
                }
            }

            const child: *Self = try parser.parseElement(alloc, label, token);
            if (first == null) first = child;
            if (last) |last_val| last_val.next_sibling = child;
            last = child;

            token = try parser.getNextToken();
            switch (token.type) {
                end_token_type => break,
                .comma => {},
                else => { std.log.err("Expected end token with token: {t}", .{ token.type }); return JSONError.TokenUnexpected; },
            }
        }

        return first;
    }
    pub fn parseElement(parser: *Parser, alloc: std.mem.Allocator, label: ?[]const u8, token: Token) JSONError!*Self {
        const result: *Self = try alloc.create(Self);
        result.* = .{ .label = label, .value = token.value };

        switch (token.type) {
            .brace_open => result.first_child = try parser.parseList(alloc, .brace_close, true),
            .bracket_open => result.first_child = try parser.parseList(alloc, .bracket_close, false),
            .string, .number => {},
            else => { std.log.err("Unexpected Token: {t}", .{ token.type }); return JSONError.TokenUnexpected; }
        }
        return result;
    }
};
