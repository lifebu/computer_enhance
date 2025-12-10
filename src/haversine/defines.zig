const std = @import("std");

pub const earth_radius: f64 = 6372.8;
pub const max_haversine = std.math.maxInt(u32);

pub const HaversinePairs = struct {
    x0: f64,
    y0: f64,
    x1: f64,
    y1: f64,
};

pub const HaversineData = struct {
    pairs: [] HaversinePairs,
};

