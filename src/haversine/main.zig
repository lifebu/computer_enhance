const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

const calculator = @import("calculator.zig");
const generator = @import("generator.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();

    _ = args.next(); // The file itself.
    if(args.next()) |command| {
        if(std.mem.eql(u8, command, "gen")) {
            const distribution_str: ?[:0]const u8 = args.next();
            if(distribution_str == null) {
                std.log.info("[uniform/cluster] [random seed] [number of coordinate pairs to generate]", .{});
            } else {
                const use_clusters: bool = std.mem.eql(u8, distribution_str.?, "cluster");
                assert(use_clusters or std.mem.eql(u8, distribution_str.?, "uniform"));
                const seed: u64 = try std.fmt.parseInt(u64, args.next().?, 10);
                const num_coords: u64 = try std.fmt.parseInt(u64, args.next().?, 10);
                std.log.info("generate: use clusters: {}, seed: {}, num_coords: {}", .{ use_clusters, seed, num_coords });
                try generator.generateHaversine(alloc, use_clusters, seed, num_coords);
            }
        } else if(std.mem.eql(u8, command, "calc")) {
            const json_file: ?[:0]const u8 = args.next();
            if(json_file == null) {
                std.log.info("[haversine_input.json]", .{});
                std.log.info("[haversine_input.json] [answers.f64]", .{});
            } else {
                const answer_file: []const u8 = args.next() orelse "";
                try calculator.calculateHaversine(alloc, json_file.?, answer_file);
            }

        } else {
            std.log.err("Unknown command: {s}", .{ command });
        }
    } else {
        std.log.err("No command specified. use gen or calc", .{ });
    }
}
