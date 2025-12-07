const std = @import("std");
const computer_enhance = @import("computer_enhance");
const Decoder = @import("sim86/Decoder.zig");
const Instruction = @import("sim86/Instruction.zig");


pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var buf: [1024]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buf);
    defer stdout.file.unlock();

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();

    _ = args.next(); // The file itself.
    if(args.next()) |path_relative| {
        try stdout.interface.print("; {s}:\n", .{ path_relative });
        const contents = try std.fs.cwd().readFileAlloc(alloc, path_relative, 1024);
        defer alloc.free(contents);

        var decoder: Decoder = .{};
        const result: []u8 = try decoder.disAsm(alloc, contents);
        defer alloc.free(result);

        try stdout.interface.print("{s}", .{ result });
        try stdout.interface.flush();
    } else {
        std.debug.print("Error: No file specified\n", .{});
    }
}

fn dumpTextDiff(expected: []const u8, actual: []const u8) void {
    var expected_lines = std.mem.splitScalar(u8, expected, '\n');
    var actual_lines = std.mem.splitScalar(u8, actual, '\n');

    while(expected_lines.peek() != null or actual_lines.peek() != null) {
        const expected_line = if(expected_lines.next()) |nxt| nxt else "_";
        if(std.mem.startsWith(u8, expected_line, ";") or expected_line.len == 0) {
            continue;
        }

        var actual_line = if(actual_lines.next()) |nxt| nxt else "_";
        if(std.mem.endsWith(u8, expected_line, ":")) {
            // to align outputs with labels.
            actual_line = expected_line;
        }
        if(actual_line.len == 0) {
            continue;
        }

        const is_equal: bool = std.mem.eql(u8, expected_line, actual_line);
        const divider = if(is_equal) " " else "|";

        std.debug.print("{s:<30} {s} {s:<30}\n", .{ expected_line, divider, actual_line });
    }
}

test "decode" {
    const gpa = std.testing.allocator;
    const bin_actual_file = "results/result";
    const asm_actual_file = "results/result.asm";
    const test_names = [_][]const u8{
        "test_data/add_sub_cmp",
        "test_data/jnz",
        "upstream/perfaware/part1/listing_0037_single_register_mov",
        "upstream/perfaware/part1/listing_0038_many_register_mov",
        "upstream/perfaware/part1/listing_0039_more_movs",
        "upstream/perfaware/part1/listing_0040_challenge_movs",
        "upstream/perfaware/part1/listing_0041_add_sub_cmp_jnz",
        //"upstream/perfaware/part1/listing_0042_completionist_decode",
    };

    for (test_names, 0..) |test_name, test_idx| {
        const bin_file = test_name;
        const bin_expected = try std.fs.cwd().readFileAlloc(gpa, bin_file, std.math.maxInt(u32));
        defer gpa.free(bin_expected);

        const asm_file = try std.fmt.allocPrint(gpa, "{s}.asm", .{ bin_file });
        defer gpa.free(asm_file);
        const asm_expected = try std.fs.cwd().readFileAlloc(gpa, asm_file, std.math.maxInt(u32));
        defer gpa.free(asm_expected);

        var decoder: Decoder = .{};
        const asm_actual: []u8 = try decoder.disAsm(gpa, bin_expected);
        defer gpa.free(asm_actual);
        try std.fs.cwd().writeFile(.{ .data = asm_actual, .sub_path = asm_actual_file, .flags = .{} });

        var nasm = std.process.Child.init(&[_][]const u8{ "nasm", asm_actual_file }, gpa);
        try nasm.spawn();
        _ = try nasm.wait();

        const bin_actual = try std.fs.cwd().readFileAlloc(gpa, bin_actual_file, std.math.maxInt(u32));
        defer gpa.free(bin_actual);

        errdefer {
            std.debug.print("# Test: {d}: {s}\n", .{ test_idx, bin_file });
            std.debug.print("## expected:\n", .{});
            std.debug.dumpHex(bin_expected);
            std.debug.print("## actual:\n", .{});
            std.debug.dumpHex(bin_actual);
            std.debug.print("## diff:\n", .{});
            dumpTextDiff(asm_expected, asm_actual);
        }
        const min_len = @min(bin_expected.len, bin_actual.len);
        for (bin_expected[0..min_len], bin_actual[0..min_len]) |expected, actual| {
            try std.testing.expectEqual(expected, actual);
        }
        try std.testing.expectEqual(bin_expected.len, bin_actual.len);
    }
}

// Notes:
// register set that is set to 0 to start.
// implement: cmp, sub, add, mov
    // cmp = sub, but does not writes it's result. only for flags 
// flag register
    // !zf: zero-flag: was result zero?
    // !sf: signed-flag: is result signed: i.e.: is highest bit set? 
    // pf: parity-flag: even number of bits set.
    // of: overflow-flag: if this was a signed operation, would this overflowed?
    // cf: carry-flag: add two numbers: carried out the highest bit.
    // af: auxilary-flag: add two numbers: carried out the highest bit, but only for 4-bits
// instruction pointer:
    // ip is updated after decoding but before executing an instruction.
    // ip points to the next instruction we need.  
    // simulation is done when the ip is outside of the last instruction (larger than memory). 
// test "exec" {
//     const gpa = std.testing.allocator;
//     const test_names = [_][]const u8{
//         "upstream/perfaware/part1/listing_0043_immediate_movs",
//     };
//
//     for (test_names, 0..) |test_name, test_idx| {
//         const bin_file = try std.fs.cwd().readFileAlloc(gpa, test_name, std.math.maxInt(u32));
//         defer gpa.free(bin_file);
//
//         // test_name => input asembly file.
//         // test_name.txt => expected output of running the simulation.
//         // decode each instruction and run it.
//         var decoder: Decoder = .{};
//         decoder.decode(memory: []u8)
//     }
// }

