const std = @import("std");
const assert = std.debug.assert;

const Json = @import("Json.zig");

// TODO:
// Write json parser for the input file and do the haversine calculation.
pub fn calculateHaversine(alloc: std.mem.Allocator, json_file: []const u8, answer_file: []const u8) !void {
    std.debug.print("json file: {s}\n", .{ json_file });
    const json_data = try std.fs.cwd().readFileAlloc(alloc, json_file, std.math.maxInt(u32));
    defer alloc.free(json_data);

    const parsed: Json = .init(alloc, json_data);
    defer parsed.deinit();
    
    const input_size: u64 = 0; // TODO: What is that?
    const num_coords: u64 = 0;
    const sum: f64 = 0.0;

    std.debug.print("Input size: {}\n", .{ input_size });
    std.debug.print("Pair count: {}\n", .{ num_coords });
    std.debug.print("Haversine sum: {}\n", .{ sum });

    const has_answers: bool = answer_file.len != 0;
    if(has_answers) {
        const answer_data = try std.fs.cwd().readFileAlloc(alloc, answer_file, std.math.maxInt(u32));
        defer alloc.free(answer_data);

        var reference_sum: f64 = 0;
        const num_bytes = @typeInfo(@TypeOf(reference_sum)).float.bits / 8;
        const num_floats = answer_data.len / num_bytes;
        for(0..num_floats) |idx| {
            const start_idx = idx * num_bytes;
            const float_bytes = answer_data[start_idx..][0..4];
            const float: f64 = std.mem.bytesToValue(f64, float_bytes);
            reference_sum = float;
        }

        std.debug.print("\n", .{});
        std.debug.print("answer file: {s}\n", .{ answer_file });
        std.debug.print("Validation:\n", .{});
        std.debug.print("Reference sum: {}\n", .{ reference_sum });
        std.debug.print("Difference: {}\n", .{ sum - reference_sum });
    }
}
