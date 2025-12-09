const std = @import("std");

const HaversinePairs = struct {
    x0: f64,
    y0: f64,
    x1: f64,
    y1: f64,
};
const HaversineData = struct {
    pairs: []const HaversinePairs,
};

// TODO:
// generate json file that has an array of pairs. a pair has x0, y0, x1, y1 floats
pub fn generateHaversine(use_clusters: bool, seed: u64, num_coords: u64) !void {
    _ = use_clusters;
    _ = seed;
    _ = num_coords;

    const file = try std.fs.cwd().createFile("results/haversine.json", .{});
    defer file.close();

    var file_buf: [1024]u8 = undefined;
    var file_writer: std.fs.File.Writer = file.writer(&file_buf);

    var data: HaversineData = undefined;
    data.pairs = &[_]HaversinePairs{
        .{ .x0 = 0.2, .y0 = 1.2, .x1 = 2.3, .y1 = 3.4, },
        .{ .x0 = 4.5, .y0 = 5.6, .x1 = 6.7, .y1 = 7.8, },
    };
    const jsonFormatter = std.json.fmt(data, .{ .whitespace = .indent_tab });
    try jsonFormatter.format(&file_writer.interface);

    try file_writer.end();
}
