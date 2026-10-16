const std = @import("std");
const builtin = @import("builtin");

pub fn getOsTimerFreq() u64 {
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

pub fn readOsTimer() u64 {
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

pub fn readCpuTimer() u64 {
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

pub fn approxCpuFreq(ms_to_wait: u64) u64 {
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

pub fn getSeconds(os_start: u64, os_end: u64) f64 {
    const os_freq: u64 = getOsTimerFreq();
    const os_freq_flt: f64 = @floatFromInt(os_freq);

    const os_delta: u64 = os_end - os_start;
    const os_delta_flt: f64 = @floatFromInt(os_delta);
    const s_total: f64 = (os_delta_flt / os_freq_flt);
    return s_total;
}
