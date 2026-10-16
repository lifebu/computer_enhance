const std = @import("std");

const metrics = @import("haversine/metrics.zig");
test "os_metric_test" {
    const os_start: u64 = metrics.readOsTimer();
    const os_freq: u64 = metrics.getOsTimerFreq();

    var os_end: u64 = 0;
    var os_delta: u64 = 0;
    while (os_delta < os_freq) {
        os_end = metrics.readOsTimer();
        os_delta = os_end - os_start;
    }

    const os_delta_flt: f64 = @floatFromInt(os_delta);
    const os_freq_flt: f64 = @floatFromInt(os_freq);
    const os_delta_sec: f64 = os_delta_flt / os_freq_flt;
    try std.testing.expectApproxEqAbs(1.0, os_delta_sec, std.math.floatEps(f64));
}
