const std = @import("std");
const Random = @import("Random.zig");
const reference = @import("reference.zig");

const HaversinePairs = struct {
    x0: f64,
    y0: f64,
    x1: f64,
    y1: f64,
};
const HaversineData = struct {
    pairs: []const HaversinePairs,
};

// TODO: Generate some testdata with caseys reference implementation and test this code!
pub fn generateHaversine(alloc: std.mem.Allocator, use_clusters: bool, seed: u64, num_coords: u64) !void {
    const limit: u64 = 1 << 34;
    if(num_coords > limit) {
        std.debug.print("You can only generate files up to {}!\n", .{ limit });
        return;
    }

    const json_path = "results/haversine.json";
    const result_path = "results/result.f64";

    const json_file = try std.fs.cwd().createFile(json_path, .{});
    defer json_file.close();

    var json_buf: [1024]u8 = undefined;
    var json_writer: std.fs.File.Writer = json_file.writer(&json_buf);

    const result_file = try std.fs.cwd().createFile(result_path, .{});
    defer result_file.close();

    var result_buf: [1024]u8 = undefined;
    var result_writer: std.fs.File.Writer = result_file.writer(&result_buf);

    var rng: Random = .init(seed);
    var json_data: HaversineData = undefined;

    var pair_list = try std.ArrayList(HaversinePairs).initCapacity(alloc, 100);
    defer pair_list.deinit(alloc);

    const earth_radius: f64 = 6372.8;
    const max_x: f64 = 180.0;
    const max_y: f64 = 90.0;
    var center_x: f64 = 0.0;
    var center_y: f64 = 0.0;
    var radius_x: f64 = max_x;
    var radius_y: f64 = max_y;
    var sum: f64 = 0.0;
    const sum_coef: f64 = 1.0 / @as(f64, @floatFromInt(num_coords));
    var clusters_left: u64 = if(use_clusters) 0 else std.math.maxInt(u64);
    const cluster_max = 1 + (num_coords / 64);

    for(0..num_coords) |_| {
        const cluster_value: u64 = clusters_left;
        clusters_left -%= 1;
        if(cluster_value <= 0) {
            clusters_left = cluster_max;
            center_x = rng.genRange(-max_x, max_x);
            center_y = rng.genRange(-max_y, max_y);
            radius_x = rng.genRange(0, max_x);
            radius_y = rng.genRange(0, max_y);
            std.debug.print("cluster: ({}, {})-({},{})\n", .{ center_x, center_y, radius_x, radius_y });
        }

        const x0: f64 = rng.genDegree(center_x, radius_x, max_x);
        const y0: f64 = rng.genDegree(center_y, radius_y, max_y);
        const x1: f64 = rng.genDegree(center_x, radius_x, max_x);
        const y1: f64 = rng.genDegree(center_y, radius_y, max_y);
        const distance: f64 = reference.referenceHaversine(x0, y0, x1, y1, earth_radius);

        sum += sum_coef * distance;

        const new_pair: *HaversinePairs = try pair_list.addOne(alloc);
        new_pair.* = HaversinePairs{ .x0 = x0, .y0 = y0, .x1 = x1, .y1 = y1 };
        try result_writer.interface.writeAll(&std.mem.toBytes(distance));
    }

    json_data.pairs = pair_list.items;
    const jsonFormatter = std.json.fmt(json_data, .{ .whitespace = .indent_tab });
    try jsonFormatter.format(&json_writer.interface);

    try result_writer.interface.writeAll(&std.mem.toBytes(sum));

    try json_writer.end();
    try result_writer.end();

    std.debug.print("Use clusters: {}\n", .{ use_clusters });
    std.debug.print("Seed: {}\n", .{ seed });
    std.debug.print("Pair count: {}\n", .{ num_coords });
    std.debug.print("Expected sum: {}\n", .{ sum });
}
