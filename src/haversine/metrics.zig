const std = @import("std");
const assert = std.debug.assert;
const builtin = @import("builtin");

const max_stack = 10;
const max_sections = 10;
const Section = struct { name: []const u8 = "", begin: u64 = 0, end: u64 = 0 };

var stack: [max_stack]Section = @splat(.{});
var next_stack: std.math.IntFittingRange(0, max_stack) = 0;
var sections: [max_sections]Section = @splat(.{});
var next_section: std.math.IntFittingRange(0, max_sections) = 0;
var total_os_start: u64 = 0;
var total_cpu_start: u64 = 0;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Interface

pub fn beginProfile() void {
    total_os_start = readOsTimer();
    total_cpu_start = readCpuTimer();
    next_stack = 0;
    next_section = 0;
}
pub fn endAndPrintProfile() void {
    if (next_stack != 0) @panic("Some profiling scopes were not popped when profiling ended");
    const total_cpu_end: u64 = readCpuTimer();
    const total_os_end: u64 = readOsTimer();
    const total_cpu_delta: f64 = @floatFromInt(total_cpu_end - total_cpu_start);

    const cpu_freq: u64 = approxCpuFreq(100);
    const os_freq: f64 = @floatFromInt(getOsTimerFreq());
    const os_delta: f64 = @floatFromInt(total_os_end - total_os_start);
    const total_ms: f64 = (os_delta / os_freq) * std.time.ms_per_s;
    std.log.info("Total time: {:.4}ms (CPU freq: {})", .{ total_ms, cpu_freq });

    if (next_section >= (sections.len - 1)) @panic("Profiling sections: OOM");
    for (sections[0..next_section]) |section| {
        const delta: f64 = @floatFromInt(section.end - section.begin);
        const percent: f64 = delta / total_cpu_delta * 100.0;
        std.log.info("\t{s}: {:.0} ({:.2}%)", .{ section.name, delta, percent });
    }
}
// TODO: What if the same scope happens multiple times? summerize the scopes?
// TODO: How to handle nested scopes (next assignment).
pub fn pushScope(comptime name: []const u8) void {
    if (next_stack >= (stack.len - 1)) @panic("Profiling section stack: OOM");
    const begin: u64 = readCpuTimer();
    stack[next_stack] = .{ .name = name, .begin = begin };
    next_stack += 1;
}
pub fn popScope() void {
    if (next_stack <= 0) @panic("No scope was created");
    if (next_section >= (sections.len - 1)) @panic("Profiling sections: OOM");
    const end: u64 = readCpuTimer();
    next_stack -= 1;
    stack[next_stack].end = end;
    sections[next_section] = stack[next_stack];
    next_section += 1;
}
pub fn pushFunc(comptime src: std.builtin.SourceLocation) void {
    pushScope(src.fn_name);
}
pub fn popFunc() void {
    popScope();
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Internals

inline fn getOsTimerFreq() u64 {
    switch (builtin.os.tag) {
        .windows => {
            var value: i64 = undefined;
            if(!std.os.windows.ntdll.RtlQueryPerformanceFrequency(&value)) {
                @panic("Query performance frequency failed!");
            }
            return @intCast(value);
        },
        .linux => {
            return 1_000_000; // usec
        },
        else => |val| @panic("getOsTimerFreq not supported on " ++ val),
    }
}

inline fn readOsTimer() u64 {
    switch (builtin.os.tag) {
        .windows => {
            var value: i64 = undefined;
            if(!std.os.windows.ntdll.RtlQueryPerformanceCounter(&value)) {
                @panic("Query performance counter failed!");
            }
            return @intCast(value);
        },
        .linux => {
            var value: std.os.linux.timeval = undefined;
            if (std.os.linux.gettimeofday(&value, null) != 0) {
                @panic("gettimeofday frequency failed!");
            }
            const freq: u64 = getOsTimerFreq();
            const sec: u64 = @intCast(value.sec);
            const usec: u64 = @intCast(value.usec);
            return (freq * sec) + usec;
        },
        else => |val| @panic("readOsTimer not supported on " ++ val),
    }
}

inline fn readCpuTimer() u64 {
    return rdtsc();
}
inline fn rdtsc() u64 {
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
