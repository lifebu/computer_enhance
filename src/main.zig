const std = @import("std");
const computer_enhance = @import("computer_enhance");
const part1 = @import("part1/8086.zig");


pub fn main() !void {
    // TODO: compile asm as part of build process?
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

        const result: []u8 = try part1.writeMnemonic(alloc, contents);
        defer alloc.free(result);


        try stdout.interface.print("{s}", .{ result });
        try stdout.interface.flush();
    } else {
        std.debug.print("Error: No file specified\n", .{});
    }
}

fn runCommand(argv: []const []const u8, allocator: std.mem.Allocator) ![]u8 {
    var cmd = std.process.Child.init(argv, allocator);
    cmd.stdout_behavior = .Pipe;
    try cmd.spawn();

    const result = try cmd.stdout.?.readToEndAlloc(allocator, std.math.maxInt(u32));
    errdefer allocator.free(result);

    _ = try cmd.wait();
    return result;
}

test "decode" {
    const gpa = std.testing.allocator;
    const test_folder = "upstream/perfaware/part1/";
    const bin_actual_file = "results/result";
    const asm_actual_file = "results/result.asm";
    const grep_asm_expected_file = "results/grep_expected.asm";
    const grep_asm_actual_file = "results/grep_result.asm";
    const test_names = [_][]const u8{
        "listing_0037_single_register_mov",
        "listing_0038_many_register_mov",
        "listing_0039_more_movs",
    };

    for (test_names, 0..) |test_name, test_idx| {
        // create new binary.
        const bin_file = try std.fmt.allocPrint(gpa, "{s}{s}", .{ test_folder, test_name });
        defer gpa.free(bin_file);
        const bin_expected = try std.fs.cwd().readFileAlloc(gpa, bin_file, std.math.maxInt(u32));
        defer gpa.free(bin_expected);

        // TODO: Do that for each line (first create instructions struct, then print to buffer).
        const asm_actual: []u8 = try part1.writeMnemonic(gpa, bin_expected);
        defer gpa.free(asm_actual);
        try std.fs.cwd().writeFile(.{ .data = asm_actual, .sub_path = asm_actual_file, .flags = .{} });

        const nasm_result = try runCommand(&[_][]const u8{ "nasm", asm_actual_file }, gpa);
        defer gpa.free(nasm_result);

        const bin_actual = try std.fs.cwd().readFileAlloc(gpa, bin_actual_file, std.math.maxInt(u32));
        defer gpa.free(bin_actual);

        // create text diff
        const asm_file = try std.fmt.allocPrint(gpa, "{s}.asm", .{ bin_file });
        defer gpa.free(asm_file);
        const asm_expected = try std.fs.cwd().readFileAlloc(gpa, asm_file, std.math.maxInt(u32));
        defer gpa.free(asm_expected);

        const grep_asm_expected = try runCommand(&[_][]const u8{ "grep", "-Ev", "^\\s*(;|$)", asm_file }, gpa);
        defer gpa.free(grep_asm_expected);
        try std.fs.cwd().writeFile(.{ .data = grep_asm_expected, .sub_path = grep_asm_expected_file, .flags = .{} });

        const grep_asm_actual = try runCommand(&[_][]const u8{ "grep", "-Ev", "^\\s*(;|$)", asm_actual_file }, gpa);
        defer gpa.free(grep_asm_actual);
        try std.fs.cwd().writeFile(.{ .data = grep_asm_actual, .sub_path = grep_asm_actual_file, .flags = .{} });

        const diff_result = try runCommand(&[_][]const u8{ "diff", "-y", grep_asm_actual_file, grep_asm_expected_file }, gpa);
        defer gpa.free(diff_result);

        // tests
        errdefer {
            std.debug.print("Test: {d}: {s}\n", .{ test_idx, bin_file });
            std.debug.print("expected:\n", .{});
            std.debug.dumpHex(bin_expected);
            std.debug.print("actual:\n", .{});
            std.debug.dumpHex(bin_actual);
            std.debug.print("diff:\n", .{});
            std.debug.print("{s}\n", .{ diff_result });
        }
        const min_len = @min(bin_expected.len, bin_actual.len);
        for (bin_expected[0..min_len], bin_actual[0..min_len]) |expected, actual| {
            try std.testing.expectEqual(expected, actual);
        }
        try std.testing.expectEqual(bin_expected.len, bin_actual.len);
    }
}
