const std = @import("std");
const assert = std.debug.assert;

const def = @import("defines.zig");
const Json = @import("Json.zig");
const reference = @import("reference.zig");
const metrics = @import("metrics.zig");

pub fn calculateHaversine(io: std.Io, alloc: std.mem.Allocator, args: *std.process.Args.Iterator) !void {
    const total_os_start: u64 = metrics.readOsTimer();
    const total_cpu_start: u64 = metrics.readCpuTimer();

    const json_file: [:0]const u8 = args.next() orelse "";
    const answer_file: []const u8 = args.next() orelse "";
    if(json_file.len == 0) {
        std.log.info("[haversine_input.json]", .{});
        std.log.info("[haversine_input.json] [answers.f64]", .{});
        return;
    }
    std.log.info("json file: {s}", .{ json_file });

    const read_file_cpu_start: u64 = metrics.readCpuTimer();
    const json_data = try std.Io.Dir.cwd().readFileAlloc(io, json_file, alloc, .limited(std.math.maxInt(u32)));
    defer alloc.free(json_data);
    std.log.info("Input size: {}", .{ json_data.len });

    const setup_cpu_start: u64 = metrics.readCpuTimer();
    const max_pairs = (json_data.len - 18) / 123; // lower limit found through testing.
    var haversine_data: def.HaversineData = .{
        .pairs = try alloc.alloc(def.HaversinePairs, max_pairs),
    };
    defer alloc.free(haversine_data.pairs);

    const json_cpu_start: u64 = metrics.readCpuTimer();
    var parsed: *Json = try .init(alloc, json_data);
    defer parsed.deinit(alloc);

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

    const sum_cpu_start: u64 = metrics.readCpuTimer();
    var sum: f64 = 0.0;
    const sum_coef: f64 = 1.0 / @as(f64, @floatFromInt(pair_count));
    for(0..pair_count) |idx| {
        const pair: def.HaversinePairs = haversine_data.pairs[idx];
        const distance: f64 = reference.referenceHaversine(pair.x0, pair.y0, pair.x1, pair.y1, def.earth_radius);
        sum += distance * sum_coef;
    }

    const output_cpu_start: u64 = metrics.readCpuTimer();
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

    const total_cpu_end: u64 = metrics.readCpuTimer();
    const total_cpu_delta: u64 = total_cpu_end - total_cpu_start;
    const total_os_end: u64 = metrics.readOsTimer();
    const cpu_freq: u64 = metrics.approxCpuFreq(100);
    const os_freq: u64 = metrics.getOsTimerFreq();
    const total_ms: f64 = metrics.getSeconds(os_freq, total_os_start, total_os_end) * std.time.ms_per_s;
    std.log.info("Total time: {:.4}ms (CPU freq: {})", .{ total_ms, cpu_freq });

    metrics.logDelta("Startup", total_cpu_delta, total_cpu_start, read_file_cpu_start);
    metrics.logDelta("Read", total_cpu_delta, read_file_cpu_start, setup_cpu_start);
    metrics.logDelta("Setup", total_cpu_delta, setup_cpu_start, json_cpu_start);
    metrics.logDelta("Json", total_cpu_delta, json_cpu_start, sum_cpu_start);
    metrics.logDelta("Sum", total_cpu_delta, sum_cpu_start, output_cpu_start);
    metrics.logDelta("Output", total_cpu_delta, sum_cpu_start, total_cpu_end);
}
