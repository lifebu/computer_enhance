const std = @import("std");
const assert = std.debug.assert;

const def = @import("defines.zig");
const Json = @import("Json.zig");
const reference = @import("reference.zig");
const metrics = @import("metrics.zig");

pub fn calculateHaversine(io: std.Io, alloc: std.mem.Allocator, args: *std.process.Args.Iterator) !void {
    metrics.beginProfile(); 
    defer metrics.endAndPrintProfile();

    const json_file: [:0]const u8 = args.next() orelse "";
    const answer_file: []const u8 = args.next() orelse "";
    if(json_file.len == 0) {
        std.log.info("[haversine_input.json]", .{});
        std.log.info("[haversine_input.json] [answers.f64]", .{});
        return;
    }
    std.log.info("json file: {s}", .{ json_file });

    metrics.pushScope("ReadEntireFile");
    const file: std.Io.File = try std.Io.Dir.cwd().openFile(io, json_file, .{});
    const file_stat: std.Io.File.Stat = try file.stat(io);

    metrics.pushScopeData("readFileAlloc", file_stat.size);
    const json_data = try std.Io.Dir.cwd().readFileAlloc(io, json_file, alloc, .limited(std.math.maxInt(u32)));
    metrics.popScopeData();
    defer alloc.free(json_data);
    std.log.info("Input size: {}", .{ json_data.len });

    const max_pairs = (json_data.len - 18) / 123; // lower limit found through testing.
    var haversine_data: def.HaversineData = .{
        .pairs = try alloc.alloc(def.HaversinePairs, max_pairs),
    };
    defer alloc.free(haversine_data.pairs);
    metrics.popScope();

    metrics.pushScope("Json");
    metrics.pushScope("Json::Parse");
    var parsed: *Json = try .init(alloc, json_data);
    defer parsed.deinit(alloc);
    metrics.popScope();

    metrics.pushScope("Json::Lookup");
    const json_parent: *Json = try parsed.getChild("pairs");
    var pair_idx: usize = 0;
    var json_pairs: ?*Json = json_parent.first_child;
    while(json_pairs) |json_elem| : ({ json_pairs = json_pairs.?.next_sibling; pair_idx += 1; }) {
        if(pair_idx > def.max_haversine) {
            break;
        }
        assert(pair_idx < haversine_data.pairs.len); // We ran out of memory!

        const x0: f64 = try json_elem.getElem("x0", f64);
        const x1: f64 = try json_elem.getElem("x1", f64);
        const y0: f64 = try json_elem.getElem("y0", f64);
        const y1: f64 = try json_elem.getElem("y1", f64);
        haversine_data.pairs[pair_idx] = .{
            .x0 = x0, .x1 = x1, .y0 = y0, .y1 = y1
        };
    }
    const pair_count = pair_idx;
    metrics.popScope();
    metrics.popScope();


    metrics.pushScopeData("Sum", pair_count * @sizeOf(def.HaversinePairs));
    var sum: f64 = 0.0;
    const sum_coef: f64 = 1.0 / @as(f64, @floatFromInt(pair_count));
    for(0..pair_count) |idx| {
        const pair: def.HaversinePairs = haversine_data.pairs[idx];
        const distance: f64 = reference.referenceHaversine(pair.x0, pair.y0, pair.x1, pair.y1, def.earth_radius);
        sum += distance * sum_coef;
    }
    metrics.popScopeData();

    std.log.info("Pair count: {}", .{ pair_count });
    std.log.info("Haversine sum: {}", .{ sum });

    const has_answers: bool = answer_file.len != 0;
    if(has_answers) {
        const answer_data = try std.Io.Dir.cwd().readFileAlloc(io, answer_file, alloc, .limited(std.math.maxInt(u32)));
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

        std.log.info("answer file: {s}", .{ answer_file });
        std.log.info("Reference sum: {}", .{ reference_sum });
        std.log.info("Difference: {}", .{ sum - reference_sum });
    }
}
