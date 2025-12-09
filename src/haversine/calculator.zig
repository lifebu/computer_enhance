const std = @import("std");

// TODO:
// Write json parser for the input file and do the haversine calculation.
pub fn calculateHaversine(alloc: std.mem.Allocator, json_file: []const u8, answer_file: []const u8) !void {
    const has_answers: bool = answer_file.len != 0;
    std.debug.print("json file: {s}\n", .{ json_file });
    std.debug.print("answer file: {s}\n", .{ answer_file });
    _ = alloc;

    const input_size: u64 = 0; // TODO: What is that?
    const num_coords: u64 = 0;
    const sum: f64 = 0.0;

    std.debug.print("Input size: {}\n", .{ input_size });
    std.debug.print("Pair count: {}\n", .{ num_coords });
    std.debug.print("Haversine sum: {}\n", .{ sum });
    if(has_answers) {
        const reference_sum: f64 = 0;
        std.debug.print("\n", .{});
        std.debug.print("Validation:\n", .{});
        std.debug.print("Reference sum: {}\n", .{ reference_sum });
        std.debug.print("Difference: {}\n", .{ sum - reference_sum });
    }
}
