const std = @import("std");
const assert = std.debug.assert;

const def = @import("defines.zig");
const Json = @import("Json.zig");

// TODO:
// Write json parser for the input file and do the haversine calculation.
pub fn calculateHaversine(alloc: std.mem.Allocator, json_file: []const u8, answer_file: []const u8) !void {
    std.debug.print("json file: {s}\n", .{ json_file });
    const json_data = try std.fs.cwd().readFileAlloc(alloc, json_file, std.math.maxInt(u32));
    defer alloc.free(json_data);

    const parsed: Json = .init(alloc, json_data);
    defer parsed.deinit();

    const json_parent: ?*Json = parsed.child("pairs");
    var pair_idx: usize = 0;
    var json_pairs: ?*Json = if(json_parent != null) json_parent.?.first_child else null;
    while(json_pairs) |json_elem| : ({ json_pairs = json_pairs.?.next_sibling; pair_idx += 1; }) {
        if(pair_idx > std.math.maxInt(u32)) {
            break;
        }

        const x0: f64 = json_elem.element("x0", f64);
        const x1: f64 = json_elem.element("x1", f64);
        const y0: f64 = json_elem.element("y0", f64);
        const y1: f64 = json_elem.element("y1", f64);
        // TODO: Have a list of haversines that we fill up!
        const haversine: def.HaversinePairs = .{ .x0 = x0, .x1 = x1, .y0 = y0, .y1 = y1 };
        std.debug.print("Parsed Haversine: ({}, {})->({}, {})\n", .{ haversine.x0, haversine.y0, haversine.x1, haversine.y1 });
    }
    
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
