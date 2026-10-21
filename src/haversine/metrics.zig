const std = @import("std");
const assert = std.debug.assert;
const builtin = @import("builtin");

const build = @import("build");

const invalid_crc = 0;
const invalid_idx = 0;

const max_sections = 4095;
const SectionIdx = std.math.IntFittingRange(0, max_sections);
const Section = struct {
    name: []const u8 = "",
    name_crc: u32 = invalid_crc,
    hit_count: u64 = 0,
    delta_exclusive: u64 = 0, // No children
    delta_inclusive: u64 = 0, // Includes children
};

const max_stack = 10;
const StackIdx = std.math.IntFittingRange(0, max_stack);
const Stack = struct {
    begin: u64 = 0,
    old_delta_inclusive: u64 = 0,
    parent_idx: SectionIdx = invalid_idx,
    section_idx: SectionIdx = invalid_idx,
};

var next_stack: StackIdx = invalid_idx + 1;
var stack: [max_stack]Stack = @splat(.{});
var next_section: SectionIdx = invalid_idx + 1;
var sections: [max_sections]Section = @splat(.{});
var current_parent: SectionIdx = invalid_idx;
var total_cpu_start: u64 = 0;


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Interface

pub fn beginProfile() void {
    current_parent = invalid_idx;
    next_stack = invalid_idx + 1;
    next_section = invalid_idx + 1;
    total_cpu_start = readCpuTimer();
}

pub fn endAndPrintProfile() void {
    const total_cpu_end: u64 = readCpuTimer();
    const total_cpu_delta: f64 = @floatFromInt(total_cpu_end - total_cpu_start);
    const cpu_freq: f64 = @floatFromInt(approxCpuFreq(100));
    const total_ms: f64 = (total_cpu_delta / cpu_freq) * std.time.ms_per_s;
    std.log.info("__METRICS__", .{});
    std.log.info("Total time: {:.4}ms (CPU freq: {})", .{ total_ms, cpu_freq });

    for (sections[(invalid_idx + 1)..next_section]) |section| {
        const exclusive_flt: f64 = @floatFromInt(section.delta_exclusive);
        const inclusive_flt: f64 = @floatFromInt(section.delta_inclusive);
        const exclusive: f64 =  (exclusive_flt / total_cpu_delta) * 100.0;
        const inclusive: f64 = (inclusive_flt / total_cpu_delta) * 100.0;
        if (inclusive == exclusive) {
            std.log.info("{s}[{}]: exclusive: {:.0} ({:.2}%)", .{ 
                section.name, section.hit_count, section.delta_exclusive, exclusive
            });
        } else {
            std.log.info("{s}[{}]: exclusive: {:.0} ({:.2}%), inclusive: ({:.2}%)", .{ 
                section.name, section.hit_count, section.delta_exclusive, exclusive, inclusive
            });
        }
    }
}

pub fn pushScope(comptime name: []const u8) void {
    if (build.skip_metric_details) return;
    if (name.len == 0) @panic("Empty name for a scope used");
    if (next_stack >= (stack.len - 1)) @panic("Profiling section stack: OOM");
    const name_crc: u32 = comptime std.hash.Crc32.hash(name);
    comptime if (name_crc == invalid_crc) @panic("Invalid crc generated.");

    const section_idx: SectionIdx = blk: {
        for(sections[0..next_section], 0..) |section, idx| {
            if (section.name_crc == name_crc) break :blk @intCast(idx);
        }
        next_section += 1; 
        break :blk next_section - 1; 
    };
    if (next_section >= (sections.len - 1)) @panic("Profiling sections: OOM");

    const section: *Section = &sections[section_idx];
    section.name_crc = name_crc;
    section.name = name;

    const new_stack: *Stack = &stack[next_stack];
    new_stack.* = .{ 
        .section_idx = section_idx, .parent_idx = current_parent, 
        .old_delta_inclusive = section.delta_inclusive
    };
    current_parent = section_idx;
    next_stack += 1;
    new_stack.begin = readCpuTimer();
}

pub fn popScope() void {
    if (build.skip_metric_details) return;
    const end: u64 = readCpuTimer();
    if (next_stack <= 0) @panic("No scope was created");

    next_stack -= 1;
    const curr_stack: *Stack = &stack[next_stack];
    const section: *Section = &sections[curr_stack.section_idx];
    const parent: *Section = &sections[curr_stack.parent_idx];
    const delta: u64 = end - curr_stack.begin;

    parent.delta_exclusive -%= delta;
    section.delta_exclusive +%= delta;
    section.delta_inclusive = curr_stack.old_delta_inclusive + delta;
    section.hit_count += 1;
    current_parent = curr_stack.parent_idx;
}

pub fn pushFunc(comptime src: std.builtin.SourceLocation) void {
    pushScope(src.file ++ "." ++ src.fn_name);
}

pub fn popFunc() void {
    popScope();
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Internals

inline fn getOsTimerFreq() u64 {
    return switch (builtin.os.tag) {
        .windows => blk: {
            var value: i64 = undefined;
            if(!std.os.windows.ntdll.RtlQueryPerformanceFrequency(&value)) {
                @panic("Query performance frequency failed!");
            }
            break: blk @intCast(value);
        },
        .linux => 1_000_000, // usec
        else => |val| @panic("getOsTimerFreq not supported on " ++ val),
    };
}

inline fn readOsTimer() u64 {
    return switch (builtin.os.tag) {
        .windows => blk: {
            var value: i64 = undefined;
            if(!std.os.windows.ntdll.RtlQueryPerformanceCounter(&value)) {
                @panic("Query performance counter failed!");
            }
            break: blk @intCast(value);
        },
        .linux => blk: {
            var value: std.os.linux.timeval = undefined;
            if (std.os.linux.gettimeofday(&value, null) != 0) {
                @panic("gettimeofday frequency failed!");
            }
            const freq: u64 = getOsTimerFreq();
            const sec: u64 = @intCast(value.sec);
            const usec: u64 = @intCast(value.usec);
            break: blk (freq * sec) + usec;
        },
        else => |val| @panic("readOsTimer not supported on " ++ val),
    };
}

inline fn readCpuTimer() u64 {
    var hi: u32 = undefined;
    var low: u32 = undefined;
    asm (
        \\rdtscp
        : [low] "={eax}" (low),
          [hi] "={edx}" (hi),
    );
    return (@as(u64, hi) << 32) | @as(u64, low);
}

inline fn approxCpuFreq(ms_to_wait: u64) u64 {
    const os_freq: u64 = getOsTimerFreq();
    const wait_time: u64 = (os_freq * ms_to_wait) / 1_000;

    const cpu_begin: u64 = readCpuTimer();
    const os_begin: u64 = readOsTimer();
    var   os_final: u64 = 0;
    var   os_delta: u64 = 0;
    while (os_delta < wait_time) {
        os_final = readOsTimer();
        os_delta = os_final - os_begin;
    }

    const cpu_final: u64 = readCpuTimer();
    const cpu_delta: u64 = cpu_final - cpu_begin;
    const cpu_freq: u64 = (os_freq * cpu_delta) / os_delta;
    return cpu_freq;
}
