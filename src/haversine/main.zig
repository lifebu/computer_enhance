const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

const generator = @import("generator.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var buf: [1024]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buf);
    // TODO: Don't know why this breaks on windows!
    if(builtin.os.tag != .windows) {
        defer stdout.file.unlock();
    }

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();

    _ = args.next(); // The file itself.
    if(args.next()) |command| {
        if(std.mem.eql(u8, command, "gen")) {
            const distribution_str: ?[:0]const u8 = args.next();
            if(distribution_str == null) {
                try stdout.interface.print("[uniform/cluster] [random seed] [number of coordinate pairs to generate]\n", .{});
            } else {
                const use_clusters: bool = std.mem.eql(u8, distribution_str.?, "cluster");
                assert(use_clusters or std.mem.eql(u8, distribution_str.?, "uniform"));
                const seed: u64 = try std.fmt.parseInt(u64, args.next().?, 10);
                const num_coords: u64 = try std.fmt.parseInt(u64, args.next().?, 10);
                try stdout.interface.print("generate: use clusters: {}, seed: {}, num_coords: {}\n", .{ use_clusters, seed, num_coords });
                try generator.generateHaversine(alloc, use_clusters, seed, num_coords);
            }
        } else {
            try stdout.interface.print("Unknown command: {s}\n", .{ command });
        }
    } else {
        try stdout.interface.print("Error: No file specified\n", .{ });
    }

    try stdout.interface.flush();
}
