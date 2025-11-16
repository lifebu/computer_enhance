const std = @import("std");
const computer_enhance = @import("computer_enhance");
const part1 = @import("part1/8086.zig");


pub fn main() !void {
    // TODO: compile asm as part of build process?
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();

    _ = args.next(); // The file itself.
    if(args.next()) |path_relative| {
        std.debug.print("; {s}:\n", .{ path_relative });
        const contents = try std.fs.cwd().readFileAlloc(alloc, path_relative, 1024);
        defer alloc.free(contents);

        const result: []u8 = try part1.writeMnemonic(alloc, contents);
        defer alloc.free(result);

        std.debug.print("{s}", .{ result });
    } else {
        std.debug.print("Error: No file specified\n", .{});
    }
}

test "decode" {
    // TODO: my code generates a valid .asm file. Write that to disc. use nasm to compile and then compare binaries (diff in linux).

    const gpa = std.testing.allocator;

    const test_files = [_][]const u8{
        "upstream/perfaware/part1/listing_0037_single_register_mov",
    };

    for (test_files) |test_file| {
        const file_bin = test_file;
        const content_bin = try std.fs.cwd().readFileAlloc(gpa, file_bin, std.math.maxInt(u32));
        defer gpa.free(content_bin);

        const file_asm = try std.fmt.allocPrint(gpa, "{s}.asm", .{ test_file });
        const content_asm = try std.fs.cwd().readFileAlloc(gpa, file_asm, std.math.maxInt(u32));
        defer gpa.free(content_asm);

        const content_parsed: []u8 = try part1.writeMnemonic(gpa, file_asm);
        defer gpa.free(content_parsed);
        
        var line_idx: usize = 0;
        for (file_asm) |asm_line| {
            if(asm_line.len == 0 or asm_line[0] == ';' or std.mem.eql(u8, "\n", asm_line)) {
                continue;
            }

            try std.testing.expectEqualSlices(u8, asm_line, content_parsed[line_idx]);
            line_idx += 1;
        }
    }

    // TODO: Use the .asm file and the compiled binary and compare them. Skip all lines in the .asm files starting with ; and empty lines!
    // TODO: Use a list of files!
    const path_relative = "upstream/perfaware/part1/listing_0037_single_register_mov";
    const contents = try std.fs.cwd().readFileAlloc(gpa, path_relative, 1024);
    defer gpa.free(contents);
    for (contents) |byte| {
        try std.testing.expectEqual(10, byte);
    }
}
