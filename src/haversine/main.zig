const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

const calculator = @import("calculator.zig");
const generator = @import("generator.zig");
const metrics = @import("metrics.zig");

pub fn main(init: std.process.Init) !void {
    const cpu_freq: u64 = metrics.approxCpuFreq(100);
    const cpu_start: u64 = metrics.readCpuTimer();
    const os_start: u64 = metrics.readOsTimer();
    defer {
        const os_end: u64 = metrics.readOsTimer();
        const ms_total: f64 = metrics.getSeconds(os_start, os_end) * std.time.ms_per_s;
        std.log.info("Total time: {:.4}ms (CPU freq: {})", .{ ms_total, cpu_freq });

        const cpu_end: u64 = metrics.readCpuTimer();
        const cpu_delta: u64 = cpu_end - cpu_start;
        std.log.info("CPU Elapsed: {}", .{ cpu_delta });
    }


    var args = init.minimal.args.iterate();
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
                try generator.generateHaversine(init.io, init.gpa, use_clusters, seed, num_coords);
            }
        } else if(std.mem.eql(u8, command, "calc")) {
            const json_file: ?[:0]const u8 = args.next();
            if(json_file == null) {
                std.log.info("[haversine_input.json]", .{});
                std.log.info("[haversine_input.json] [answers.f64]", .{});
            } else {
                const answer_file: []const u8 = args.next() orelse "";
                try calculator.calculateHaversine(init.io, init.gpa, json_file.?, answer_file);
            }

        } else {
            std.log.err("Unknown command: {s}", .{ command });
        }
    } else {
        std.log.err("No command specified. use gen or calc", .{ });
    }
}
