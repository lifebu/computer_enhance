const std = @import("std");

pub const HaversinePairs = struct {
    x0: f64,
    y0: f64,
    x1: f64,
    y1: f64,
};

pub const HaversineData = struct {
    pairs: []const HaversinePairs,
};

